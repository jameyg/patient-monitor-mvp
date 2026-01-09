defmodule PatientMonitor.Commanded.Aggregates.Patient do
  @moduledoc """
  Patient aggregate for event sourcing.
  Handles vitals recording and alert triggering based on NEWS2 scores.
  """
  defstruct [
    :patient_id,
    :name,
    :pathway_start_date,
    :registered_at,
    :current_vitals,
    :current_news2_score,
    :active_escalation_id,
    vitals_history: []
  ]

  alias __MODULE__
  alias PatientMonitor.Commanded.Commands.{RegisterPatient, RecordVitals, AcknowledgeAlert}

  alias PatientMonitor.Commanded.Events.{
    PatientRegistered,
    VitalsRecorded,
    AlertTriggered,
    AlertAcknowledged
  }

  alias PatientMonitor.NEWS2

  # Command: Register Patient
  def execute(%Patient{patient_id: nil}, %RegisterPatient{} = cmd) do
    %PatientRegistered{
      patient_id: cmd.patient_id,
      name: cmd.name,
      pathway_start_date: cmd.pathway_start_date || Date.utc_today(),
      registered_at: DateTime.utc_now()
    }
  end

  def execute(%Patient{patient_id: _}, %RegisterPatient{}) do
    {:error, :patient_already_registered}
  end

  # Command: Record Vitals
  def execute(%Patient{patient_id: nil}, %RecordVitals{}) do
    {:error, :patient_not_found}
  end

  def execute(%Patient{} = patient, %RecordVitals{} = cmd) do
    vitals = %{
      spo2: cmd.spo2,
      heart_rate: cmd.heart_rate,
      respiratory_rate: cmd.respiratory_rate,
      temperature: cmd.temperature,
      systolic_bp: cmd.systolic_bp,
      consciousness: cmd.consciousness,
      supplemental_o2: cmd.supplemental_o2
    }

    {news2_score, risk_level} = NEWS2.calculate(vitals)
    recorded_at = cmd.recorded_at || DateTime.utc_now()

    vitals_event = %VitalsRecorded{
      patient_id: cmd.patient_id,
      spo2: cmd.spo2,
      heart_rate: cmd.heart_rate,
      respiratory_rate: cmd.respiratory_rate,
      temperature: cmd.temperature,
      systolic_bp: cmd.systolic_bp,
      consciousness: cmd.consciousness,
      supplemental_o2: cmd.supplemental_o2,
      news2_score: news2_score,
      news2_risk_level: risk_level,
      recorded_at: recorded_at
    }

    # Check if we need to trigger an alert
    if should_trigger_alert?(patient, news2_score, vitals) do
      escalation_id = Ecto.UUID.generate()

      alert_event = %AlertTriggered{
        patient_id: cmd.patient_id,
        escalation_id: escalation_id,
        trigger_reason: determine_trigger_reason(news2_score, vitals),
        trigger_value: news2_score,
        news2_score: news2_score,
        triggered_at: recorded_at
      }

      [vitals_event, alert_event]
    else
      vitals_event
    end
  end

  # Command: Acknowledge Alert
  def execute(%Patient{active_escalation_id: nil}, %AcknowledgeAlert{}) do
    {:error, :no_active_escalation}
  end

  def execute(%Patient{active_escalation_id: esc_id} = _patient, %AcknowledgeAlert{
        escalation_id: esc_id
      } = cmd) do
    %AlertAcknowledged{
      patient_id: cmd.patient_id,
      escalation_id: cmd.escalation_id,
      acknowledged_by: cmd.acknowledged_by,
      acknowledged_at: DateTime.utc_now()
    }
  end

  def execute(%Patient{}, %AcknowledgeAlert{}) do
    {:error, :escalation_mismatch}
  end

  # State mutations
  def apply(%Patient{} = patient, %PatientRegistered{} = event) do
    %Patient{
      patient
      | patient_id: event.patient_id,
        name: event.name,
        pathway_start_date: event.pathway_start_date,
        registered_at: event.registered_at
    }
  end

  def apply(%Patient{} = patient, %VitalsRecorded{} = event) do
    vitals = %{
      spo2: event.spo2,
      heart_rate: event.heart_rate,
      respiratory_rate: event.respiratory_rate,
      temperature: event.temperature,
      systolic_bp: event.systolic_bp,
      consciousness: event.consciousness,
      supplemental_o2: event.supplemental_o2,
      recorded_at: event.recorded_at
    }

    # Keep last 10 readings in aggregate (full history in projection)
    history = Enum.take([vitals | patient.vitals_history], 10)

    %Patient{
      patient
      | current_vitals: vitals,
        current_news2_score: event.news2_score,
        vitals_history: history
    }
  end

  def apply(%Patient{} = patient, %AlertTriggered{} = event) do
    %Patient{patient | active_escalation_id: event.escalation_id}
  end

  def apply(%Patient{} = patient, %AlertAcknowledged{}) do
    %Patient{patient | active_escalation_id: nil}
  end

  # Private helpers
  defp should_trigger_alert?(%Patient{active_escalation_id: esc_id}, _, _)
       when not is_nil(esc_id) do
    # Already have an active escalation
    false
  end

  defp should_trigger_alert?(_, news2_score, vitals) do
    # Trigger on NEWS2 >= 5 OR critical vital
    news2_score >= 5 or vitals.spo2 < 88 or vitals.heart_rate > 130 or vitals.heart_rate < 40
  end

  defp determine_trigger_reason(news2_score, vitals) do
    cond do
      vitals.spo2 != nil and vitals.spo2 < 88 -> "spo2_critical"
      vitals.heart_rate != nil and (vitals.heart_rate > 130 or vitals.heart_rate < 40) -> "hr_critical"
      news2_score >= 7 -> "news2_high"
      news2_score >= 5 -> "news2_medium"
      true -> "threshold_breach"
    end
  end
end
