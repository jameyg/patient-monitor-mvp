defmodule PatientMonitor.Workers.EscalationStepWorker do
  @moduledoc """
  Executes escalation workflow steps. Each step:
  1. Notifies the appropriate responder (nurse, senior clinician, on-call doctor)
  2. Sets a deadline for acknowledgement
  3. Schedules the next step if not acknowledged in time

  This implements a manual workflow pattern for Oban free version.
  """
  use Oban.Worker,
    queue: :escalations,
    max_attempts: 3

  alias PatientMonitor.Escalations

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"escalation_id" => escalation_id, "step" => step, "action" => "timeout_check"}}) do
    handle_timeout_check(escalation_id, step)
  end

  def perform(%Oban.Job{args: %{"escalation_id" => escalation_id, "step" => step}}) do
    case Escalations.get_escalation(escalation_id) do
      nil ->
        {:error, :escalation_not_found}

      %{status: "acknowledged"} ->
        :ok

      %{status: "completed"} ->
        :ok

      escalation ->
        execute_step(escalation, step)
    end
  end

  defp handle_timeout_check(escalation_id, step) do
    case Escalations.get_escalation(escalation_id) do
      nil ->
        :ok

      %{status: "acknowledged"} ->
        Escalations.complete_step(escalation_id, step, "acknowledged")
        :ok

      %{current_step: current_step} = escalation when current_step == step ->
        # Still on this step - timeout, escalate
        Escalations.complete_step(escalation_id, step, "timeout")

        # Schedule next step
        next_step = step + 1

        if next_step <= 3 do
          %{escalation_id: escalation.id, step: next_step}
          |> __MODULE__.new()
          |> Oban.insert()
        else
          # All steps exhausted
          Escalations.complete_escalation(escalation_id, "unacknowledged")
        end

        :ok

      _ ->
        :ok
    end
  end

  defp execute_step(escalation, step) when step > 3 do
    Escalations.complete_escalation(escalation.id, "unacknowledged")
    :ok
  end

  defp execute_step(escalation, step) do
    timeout_seconds = Escalations.step_timeout(step)
    step_name = Escalations.step_name(step)
    deadline = DateTime.add(DateTime.utc_now(), timeout_seconds, :second)

    # Update escalation state
    Escalations.start_step(escalation.id, step, step_name, deadline)

    # Schedule timeout check
    %{escalation_id: escalation.id, step: step, action: "timeout_check"}
    |> __MODULE__.new(schedule_in: timeout_seconds)
    |> Oban.insert()

    :ok
  end
end
