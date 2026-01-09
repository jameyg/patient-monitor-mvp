defmodule PatientMonitor.Patients.PatientProjection do
  @moduledoc """
  Read model for patient data, denormalized for quick display.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "patient_projections" do
    field :patient_id, :string
    field :name, :string
    field :pathway_day, :integer, default: 1
    field :pathway_start_date, :date
    field :status, :string, default: "active"

    field :latest_spo2, :integer
    field :latest_heart_rate, :integer
    field :latest_respiratory_rate, :integer
    field :latest_temperature, :decimal
    field :latest_systolic_bp, :integer
    field :latest_consciousness, :string
    field :latest_supplemental_o2, :boolean
    field :latest_news2_score, :integer
    field :vitals_updated_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(patient, attrs) do
    patient
    |> cast(attrs, [
      :patient_id,
      :name,
      :pathway_day,
      :pathway_start_date,
      :status,
      :latest_spo2,
      :latest_heart_rate,
      :latest_respiratory_rate,
      :latest_temperature,
      :latest_systolic_bp,
      :latest_consciousness,
      :latest_supplemental_o2,
      :latest_news2_score,
      :vitals_updated_at
    ])
    |> validate_required([:patient_id, :name])
    |> unique_constraint(:patient_id)
  end

  def vitals_changeset(patient, attrs) do
    patient
    |> cast(attrs, [
      :latest_spo2,
      :latest_heart_rate,
      :latest_respiratory_rate,
      :latest_temperature,
      :latest_systolic_bp,
      :latest_consciousness,
      :latest_supplemental_o2,
      :latest_news2_score,
      :vitals_updated_at
    ])
  end
end
