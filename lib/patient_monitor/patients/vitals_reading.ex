defmodule PatientMonitor.Patients.VitalsReading do
  @moduledoc """
  Historical vitals readings for trend analysis.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "vitals_readings" do
    field :patient_id, :string
    field :recorded_at, :utc_datetime

    field :spo2, :integer
    field :heart_rate, :integer
    field :respiratory_rate, :integer
    field :temperature, :decimal
    field :systolic_bp, :integer
    field :consciousness, :string
    field :supplemental_o2, :boolean

    field :news2_score, :integer
    field :news2_risk_level, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(reading, attrs) do
    reading
    |> cast(attrs, [
      :patient_id,
      :recorded_at,
      :spo2,
      :heart_rate,
      :respiratory_rate,
      :temperature,
      :systolic_bp,
      :consciousness,
      :supplemental_o2,
      :news2_score,
      :news2_risk_level
    ])
    |> validate_required([:patient_id, :recorded_at])
  end
end
