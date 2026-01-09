defmodule PatientMonitor.Repo.Migrations.CreatePatientProjections do
  use Ecto.Migration

  def change do
    create table(:patient_projections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :patient_id, :string, null: false
      add :name, :string, null: false
      add :pathway_day, :integer, default: 1
      add :pathway_start_date, :date
      add :status, :string, default: "active"

      add :latest_spo2, :integer
      add :latest_heart_rate, :integer
      add :latest_respiratory_rate, :integer
      add :latest_temperature, :decimal
      add :latest_systolic_bp, :integer
      add :latest_consciousness, :string
      add :latest_supplemental_o2, :boolean
      add :latest_news2_score, :integer
      add :vitals_updated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:patient_projections, [:patient_id])
  end
end
