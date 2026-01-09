defmodule PatientMonitor.Commanded.Router do
  @moduledoc """
  Command router for dispatching commands to aggregates.
  """
  use Commanded.Commands.Router

  alias PatientMonitor.Commanded.Aggregates.Patient
  alias PatientMonitor.Commanded.Commands.{
    RegisterPatient,
    RecordVitals,
    AcknowledgeAlert
  }

  identify(Patient, by: :patient_id)

  dispatch(RegisterPatient, to: Patient)
  dispatch(RecordVitals, to: Patient)
  dispatch(AcknowledgeAlert, to: Patient)
end
