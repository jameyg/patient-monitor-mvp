defmodule PatientMonitor.Commanded.Events.AlertAcknowledged do
  @moduledoc """
  Event emitted when an alert is acknowledged by a clinician.
  """
  @derive Jason.Encoder
  defstruct [:patient_id, :escalation_id, :acknowledged_by, :acknowledged_at]
end
