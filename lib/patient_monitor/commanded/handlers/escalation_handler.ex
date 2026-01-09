defmodule PatientMonitor.Commanded.Handlers.EscalationHandler do
  @moduledoc """
  Event handler that triggers Oban workflows on alert events.
  """
  use Commanded.Event.Handler,
    application: PatientMonitor.Commanded.App,
    name: __MODULE__,
    start_from: :origin

  alias PatientMonitor.Commanded.Events.{AlertTriggered, AlertAcknowledged}
  alias PatientMonitor.Escalations
  alias PatientMonitor.Workers.EscalationStepWorker

  def handle(%AlertTriggered{} = event, _metadata) do
    # Create escalation record
    {:ok, escalation} =
      Escalations.create_escalation(%{
        id: event.escalation_id,
        patient_id: event.patient_id,
        trigger_event: event.trigger_reason,
        trigger_value: event.trigger_value
      })

    # Start the escalation workflow (Step 1)
    %{escalation_id: escalation.id, step: 1}
    |> EscalationStepWorker.new()
    |> Oban.insert()

    :ok
  end

  def handle(%AlertAcknowledged{} = event, _metadata) do
    Escalations.acknowledge_escalation(
      event.escalation_id,
      event.acknowledged_by,
      event.acknowledged_at
    )

    :ok
  end
end
