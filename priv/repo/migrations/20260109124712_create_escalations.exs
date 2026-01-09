defmodule PatientMonitor.Repo.Migrations.CreateEscalations do
  use Ecto.Migration

  def change do
    create table(:escalations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :patient_id, :string, null: false
      add :trigger_event, :string
      add :trigger_value, :integer

      add :status, :string, default: "active"
      add :current_step, :integer, default: 1
      add :acknowledged_by, :string
      add :acknowledged_at, :utc_datetime

      add :step1_deadline, :utc_datetime
      add :step2_deadline, :utc_datetime
      add :step3_deadline, :utc_datetime

      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:escalations, [:patient_id])
    create index(:escalations, [:status])
  end
end
