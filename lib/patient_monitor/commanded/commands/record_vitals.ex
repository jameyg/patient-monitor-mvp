defmodule PatientMonitor.Commanded.Commands.RecordVitals do
  @moduledoc """
  Command to record vital signs for a patient.
  """
  @enforce_keys [:patient_id]
  defstruct [
    :patient_id,
    :spo2,
    :heart_rate,
    :respiratory_rate,
    :temperature,
    :systolic_bp,
    :consciousness,
    :supplemental_o2,
    :recorded_at
  ]
end
