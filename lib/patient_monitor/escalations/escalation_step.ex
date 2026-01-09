defmodule PatientMonitor.Escalations.EscalationStep do
  @moduledoc """
  Tracks individual steps within an escalation workflow.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "escalation_steps" do
    field :step_number, :integer
    field :step_type, :string

    field :status, :string, default: "pending"
    field :notified_at, :utc_datetime
    field :deadline, :utc_datetime
    field :completed_at, :utc_datetime
    field :outcome, :string

    belongs_to :escalation, PatientMonitor.Escalations.Escalation

    timestamps(type: :utc_datetime)
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [
      :escalation_id,
      :step_number,
      :step_type,
      :status,
      :notified_at,
      :deadline,
      :completed_at,
      :outcome
    ])
    |> validate_required([:step_number, :step_type])
  end
end
