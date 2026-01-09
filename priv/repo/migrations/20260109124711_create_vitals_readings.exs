defmodule PatientMonitor.Repo.Migrations.CreateVitalsReadings do
  use Ecto.Migration

  def change do
    create table(:vitals_readings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :patient_id, :string, null: false
      add :recorded_at, :utc_datetime, null: false

      add :spo2, :integer
      add :heart_rate, :integer
      add :respiratory_rate, :integer
      add :temperature, :decimal
      add :systolic_bp, :integer
      add :consciousness, :string
      add :supplemental_o2, :boolean

      add :news2_score, :integer
      add :news2_risk_level, :string

      timestamps(type: :utc_datetime)
    end

    create index(:vitals_readings, [:patient_id, :recorded_at])
  end
end
