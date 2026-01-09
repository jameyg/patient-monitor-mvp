defmodule PatientMonitor.Escalations do
  @moduledoc """
  Context for escalation workflow management.
  """
  import Ecto.Query
  alias PatientMonitor.Repo
  alias PatientMonitor.Escalations.{Escalation, EscalationStep}
  alias PatientMonitor.ActivityLog

  # Step timeouts in seconds (demo-friendly)
  @step_timeouts %{1 => 30, 2 => 20, 3 => 15}
  @step_names %{1 => "nurse", 2 => "senior_clinician", 3 => "on_call_doctor"}

  def step_timeout(step), do: Map.get(@step_timeouts, step, 30)
  def step_name(step), do: Map.get(@step_names, step, "unknown")

  def list_active_escalations do
    Escalation
    |> where([e], e.status in ["active", "completed"])
    |> order_by([e], desc: e.started_at)
    |> preload(:steps)
    |> Repo.all()
  end

  def get_escalation(id), do: Repo.get(Escalation, id) |> Repo.preload(:steps)

  def get_escalation_by_patient(patient_id) do
    Escalation
    |> where([e], e.patient_id == ^patient_id and e.status in ["active", "completed"])
    |> preload(:steps)
    |> Repo.one()
  end

  def create_escalation(attrs) do
    now = DateTime.utc_now()

    attrs =
      attrs
      |> Map.put(:started_at, now)
      |> Map.put(:step1_deadline, DateTime.add(now, @step_timeouts[1], :second))

    %Escalation{}
    |> Escalation.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, esc} ->
        log_activity(esc.patient_id, esc.id, "escalation_started", "System", %{
          trigger: esc.trigger_event,
          value: esc.trigger_value
        })
        broadcast({:escalation_created, esc})

      _ ->
        :ok
    end)
  end

  def start_step(escalation_id, step_number, step_type, deadline) do
    escalation = get_escalation(escalation_id)

    if escalation do
      # Update escalation current step - build the update map dynamically
      deadline_field = String.to_atom("step#{step_number}_deadline")
      update_attrs = Map.put(%{current_step: step_number}, deadline_field, deadline)

      {:ok, updated} =
        escalation
        |> Escalation.changeset(update_attrs)
        |> Repo.update()

      # Create step record
      {:ok, _step} =
        %EscalationStep{}
        |> EscalationStep.changeset(%{
          escalation_id: escalation_id,
          step_number: step_number,
          step_type: step_type,
          status: "active",
          notified_at: DateTime.utc_now(),
          deadline: deadline
        })
        |> Repo.insert()

      log_activity(escalation.patient_id, escalation_id, "step_started", "System", %{
        step: step_number,
        type: step_type
      })

      broadcast({:escalation_updated, updated |> Repo.preload(:steps, force: true)})
      {:ok, updated}
    else
      {:error, :not_found}
    end
  end

  def complete_step(escalation_id, step_number, outcome) do
    step =
      EscalationStep
      |> where([s], s.escalation_id == ^escalation_id and s.step_number == ^step_number)
      |> Repo.one()

    if step do
      {:ok, _} =
        step
        |> EscalationStep.changeset(%{
          status: "completed",
          completed_at: DateTime.utc_now(),
          outcome: outcome
        })
        |> Repo.update()

      escalation = get_escalation(escalation_id)

      log_activity(escalation.patient_id, escalation_id, "step_completed", "System", %{
        step: step_number,
        outcome: outcome
      })

      broadcast({:escalation_updated, escalation})
    end

    :ok
  end

  def acknowledge_escalation(escalation_id, acknowledged_by, acknowledged_at) do
    case get_escalation(escalation_id) do
      nil ->
        {:error, :not_found}

      escalation ->
        {:ok, updated} =
          escalation
          |> Escalation.changeset(%{
            status: "acknowledged",
            acknowledged_by: acknowledged_by,
            acknowledged_at: acknowledged_at,
            completed_at: acknowledged_at
          })
          |> Repo.update()

        log_activity(escalation.patient_id, escalation_id, "escalation_acknowledged", acknowledged_by, %{})
        broadcast({:escalation_updated, updated |> Repo.preload(:steps, force: true)})
        {:ok, updated}
    end
  end

  def complete_escalation(escalation_id, outcome) do
    case get_escalation(escalation_id) do
      nil ->
        {:error, :not_found}

      escalation ->
        {:ok, updated} =
          escalation
          |> Escalation.changeset(%{
            status: "completed",
            completed_at: DateTime.utc_now()
          })
          |> Repo.update()

        log_activity(escalation.patient_id, escalation_id, "escalation_completed", "System", %{
          outcome: outcome
        })

        broadcast({:escalation_updated, updated |> Repo.preload(:steps, force: true)})
        {:ok, updated}
    end
  end

  # Activity logging
  def log_activity(patient_id, escalation_id, action, actor, details) do
    %ActivityLog{}
    |> ActivityLog.changeset(%{
      patient_id: patient_id,
      escalation_id: escalation_id,
      action: action,
      actor: actor,
      details: details
    })
    |> Repo.insert()
    |> tap(fn
      {:ok, log} -> broadcast({:activity_logged, log})
      _ -> :ok
    end)
  end

  def list_recent_activity(limit \\ 20) do
    ActivityLog
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  # PubSub
  def subscribe do
    Phoenix.PubSub.subscribe(PatientMonitor.PubSub, "escalations")
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(PatientMonitor.PubSub, "escalations", message)
  end
end
