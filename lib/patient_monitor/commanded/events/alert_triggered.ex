defmodule PatientMonitor.Commanded.Events.AlertTriggered do
  @moduledoc """
  Event emitted when an alert is triggered due to concerning vitals.
  """
  @derive Jason.Encoder
  defstruct [
    :patient_id,
    :escalation_id,
    :trigger_reason,
    :trigger_value,
    :news2_score,
    :triggered_at
  ]
end
