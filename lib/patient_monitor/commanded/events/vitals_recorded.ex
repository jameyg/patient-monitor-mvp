defmodule PatientMonitor.Commanded.Events.VitalsRecorded do
  @moduledoc """
  Event emitted when vital signs are recorded for a patient.
  """
  @derive Jason.Encoder
  defstruct [
    :patient_id,
    :spo2,
    :heart_rate,
    :respiratory_rate,
    :temperature,
    :systolic_bp,
    :consciousness,
    :supplemental_o2,
    :news2_score,
    :news2_risk_level,
    :recorded_at
  ]
end
