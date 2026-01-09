defmodule PatientMonitor.Commanded.Commands.AcknowledgeAlert do
  @moduledoc """
  Command to acknowledge an active alert/escalation for a patient.
  """
  @enforce_keys [:patient_id, :escalation_id, :acknowledged_by]
  defstruct [:patient_id, :escalation_id, :acknowledged_by]
end
