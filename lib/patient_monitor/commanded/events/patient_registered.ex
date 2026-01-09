defmodule PatientMonitor.Commanded.Events.PatientRegistered do
  @moduledoc """
  Event emitted when a new patient is registered.
  """
  @derive Jason.Encoder
  defstruct [:patient_id, :name, :pathway_start_date, :registered_at]
end
