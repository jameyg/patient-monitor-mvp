defmodule PatientMonitor.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :patient_id, :string
      add :escalation_id, references(:escalations, type: :binary_id, on_delete: :nilify_all)
      add :action, :string, null: false
      add :actor, :string
      add :details, :map

      timestamps(type: :utc_datetime)
    end

    create index(:activity_logs, [:inserted_at])
  end
end
