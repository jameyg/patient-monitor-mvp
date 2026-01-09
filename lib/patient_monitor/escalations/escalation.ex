defmodule PatientMonitor.Escalations.Escalation do
  @moduledoc """
  Tracks the state of an escalation workflow.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "escalations" do
    field :patient_id, :string
    field :trigger_event, :string
    field :trigger_value, :integer

    field :status, :string, default: "active"
    field :current_step, :integer, default: 1
    field :acknowledged_by, :string
    field :acknowledged_at, :utc_datetime

    field :step1_deadline, :utc_datetime
    field :step2_deadline, :utc_datetime
    field :step3_deadline, :utc_datetime

    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    has_many :steps, PatientMonitor.Escalations.EscalationStep

    timestamps(type: :utc_datetime)
  end

  def changeset(escalation, attrs) do
    escalation
    |> cast(attrs, [
      :id,
      :patient_id,
      :trigger_event,
      :trigger_value,
      :status,
      :current_step,
      :acknowledged_by,
      :acknowledged_at,
      :step1_deadline,
      :step2_deadline,
      :step3_deadline,
      :started_at,
      :completed_at
    ])
    |> validate_required([:patient_id])
  end
end
