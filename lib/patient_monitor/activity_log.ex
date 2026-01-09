defmodule PatientMonitor.ActivityLog do
  @moduledoc """
  Schema for activity log entries.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "activity_logs" do
    field :patient_id, :string
    field :escalation_id, :binary_id
    field :action, :string
    field :actor, :string
    field :details, :map

    timestamps(type: :utc_datetime)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:patient_id, :escalation_id, :action, :actor, :details])
    |> validate_required([:action])
  end
end
