defmodule PatientMonitor.Repo.Migrations.CreateEscalationSteps do
  use Ecto.Migration

  def change do
    create table(:escalation_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :escalation_id, references(:escalations, type: :binary_id, on_delete: :delete_all)
      add :step_number, :integer, null: false
      add :step_type, :string, null: false

      add :status, :string, default: "pending"
      add :notified_at, :utc_datetime
      add :deadline, :utc_datetime
      add :completed_at, :utc_datetime
      add :outcome, :string

      timestamps(type: :utc_datetime)
    end

    create index(:escalation_steps, [:escalation_id])
  end
end
