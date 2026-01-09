defmodule PatientMonitor.Commanded.Handlers.ProjectionHandler do
  @moduledoc """
  Event handler that updates SQLite read models from domain events.
  """
  use Commanded.Event.Handler,
    application: PatientMonitor.Commanded.App,
    name: __MODULE__,
    start_from: :origin

  alias PatientMonitor.Commanded.Events.{PatientRegistered, VitalsRecorded}
  alias PatientMonitor.Patients

  def handle(%PatientRegistered{} = event, _metadata) do
    Patients.create_patient_projection(%{
      patient_id: event.patient_id,
      name: event.name,
      pathway_start_date: event.pathway_start_date,
      status: "active"
    })

    :ok
  end

  def handle(%VitalsRecorded{} = event, _metadata) do
    # Update projection with latest vitals
    Patients.update_patient_vitals(event.patient_id, %{
      latest_spo2: event.spo2,
      latest_heart_rate: event.heart_rate,
      latest_respiratory_rate: event.respiratory_rate,
      latest_temperature: event.temperature,
      latest_systolic_bp: event.systolic_bp,
      latest_consciousness: event.consciousness,
      latest_supplemental_o2: event.supplemental_o2,
      latest_news2_score: event.news2_score,
      vitals_updated_at: event.recorded_at
    })

    # Store historical reading
    Patients.create_vitals_reading(%{
      patient_id: event.patient_id,
      spo2: event.spo2,
      heart_rate: event.heart_rate,
      respiratory_rate: event.respiratory_rate,
      temperature: event.temperature,
      systolic_bp: event.systolic_bp,
      consciousness: event.consciousness,
      supplemental_o2: event.supplemental_o2,
      news2_score: event.news2_score,
      news2_risk_level: event.news2_risk_level,
      recorded_at: event.recorded_at
    })

    :ok
  end
end
