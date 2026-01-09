defmodule PatientMonitor.Commanded.Commands.RegisterPatient do
  @moduledoc """
  Command to register a new patient in the system.
  """
  @enforce_keys [:patient_id, :name]
  defstruct [:patient_id, :name, :pathway_start_date]
end
