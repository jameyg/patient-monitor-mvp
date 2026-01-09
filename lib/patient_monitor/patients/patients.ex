defmodule PatientMonitor.Patients do
  @moduledoc """
  Context for patient read models.
  """
  import Ecto.Query
  alias PatientMonitor.Repo
  alias PatientMonitor.Patients.{PatientProjection, VitalsReading}

  def list_patients do
    PatientProjection
    |> order_by([p], asc: p.patient_id)
    |> Repo.all()
  end

  def get_patient(id), do: Repo.get(PatientProjection, id)

  def get_patient_by_patient_id(patient_id) do
    Repo.get_by(PatientProjection, patient_id: patient_id)
  end

  def get_patient_with_vitals(id) do
    patient = get_patient(id)

    if patient do
      vitals =
        VitalsReading
        |> where([v], v.patient_id == ^patient.patient_id)
        |> order_by([v], desc: v.recorded_at)
        |> limit(20)
        |> Repo.all()

      Map.put(patient, :vitals_history, vitals)
    else
      nil
    end
  end

  def create_patient_projection(attrs) do
    %PatientProjection{}
    |> PatientProjection.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, patient} -> broadcast({:patient_created, patient})
      _ -> :ok
    end)
  end

  def update_patient_vitals(patient_id, attrs) do
    case get_patient_by_patient_id(patient_id) do
      nil ->
        {:error, :not_found}

      patient ->
        patient
        |> PatientProjection.vitals_changeset(attrs)
        |> Repo.update()
        |> tap(fn
          {:ok, patient} -> broadcast({:patient_updated, patient})
          _ -> :ok
        end)
    end
  end

  def create_vitals_reading(attrs) do
    %VitalsReading{}
    |> VitalsReading.changeset(attrs)
    |> Repo.insert()
  end

  def get_recent_vitals(patient_id, limit \\ 10) do
    VitalsReading
    |> where([v], v.patient_id == ^patient_id)
    |> order_by([v], desc: v.recorded_at)
    |> limit(^limit)
    |> Repo.all()
  end

  # PubSub
  def subscribe do
    Phoenix.PubSub.subscribe(PatientMonitor.PubSub, "patients")
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(PatientMonitor.PubSub, "patients", message)
  end
end
