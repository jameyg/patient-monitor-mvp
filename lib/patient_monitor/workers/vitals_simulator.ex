defmodule PatientMonitor.Workers.VitalsSimulator do
  @moduledoc """
  Generates simulated vitals for demo patients.
  Can be triggered manually or scheduled.
  """
  use Oban.Worker, queue: :default

  alias PatientMonitor.Commanded.App
  alias PatientMonitor.Commanded.Commands.RecordVitals
  alias PatientMonitor.Patients

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"patient_id" => patient_id}}) do
    vitals = generate_vitals(patient_id)

    command = %RecordVitals{
      patient_id: patient_id,
      spo2: vitals.spo2,
      heart_rate: vitals.heart_rate,
      respiratory_rate: vitals.respiratory_rate,
      temperature: vitals.temperature,
      systolic_bp: vitals.systolic_bp,
      consciousness: vitals.consciousness,
      supplemental_o2: vitals.supplemental_o2,
      recorded_at: DateTime.utc_now()
    }

    App.dispatch(command)

    :ok
  end

  def perform(%Oban.Job{args: %{"action" => "simulate_all"}}) do
    Patients.list_patients()
    |> Enum.each(fn patient ->
      %{"patient_id" => patient.patient_id}
      |> __MODULE__.new()
      |> Oban.insert()
    end)

    :ok
  end

  defp generate_vitals(patient_id) do
    patient = Patients.get_patient_by_patient_id(patient_id)

    base_spo2 = (patient && patient.latest_spo2) || 96
    base_hr = (patient && patient.latest_heart_rate) || 75

    # 15% chance of concerning vitals for demo
    if :rand.uniform(100) <= 15 do
      generate_concerning_vitals()
    else
      generate_normal_vitals(base_spo2, base_hr)
    end
  end

  defp generate_normal_vitals(base_spo2, base_hr) do
    %{
      spo2: clamp(base_spo2 + :rand.uniform(5) - 2, 94, 100),
      heart_rate: clamp(base_hr + :rand.uniform(10) - 5, 60, 100),
      respiratory_rate: 12 + :rand.uniform(8),
      temperature: Decimal.new("36.#{5 + :rand.uniform(4)}"),
      systolic_bp: 110 + :rand.uniform(30),
      consciousness: "A",
      supplemental_o2: false
    }
  end

  defp generate_concerning_vitals do
    scenario = :rand.uniform(3)

    case scenario do
      1 ->
        # Low SpO2
        %{
          spo2: 85 + :rand.uniform(5),
          heart_rate: 90 + :rand.uniform(20),
          respiratory_rate: 22 + :rand.uniform(6),
          temperature: Decimal.new("37.#{:rand.uniform(5)}"),
          systolic_bp: 100 + :rand.uniform(20),
          consciousness: "A",
          supplemental_o2: true
        }

      2 ->
        # Tachycardia
        %{
          spo2: 93 + :rand.uniform(4),
          heart_rate: 105 + :rand.uniform(30),
          respiratory_rate: 20 + :rand.uniform(8),
          temperature: Decimal.new("37.#{:rand.uniform(8)}"),
          systolic_bp: 90 + :rand.uniform(20),
          consciousness: "A",
          supplemental_o2: false
        }

      3 ->
        # High NEWS2 composite
        %{
          spo2: 91 + :rand.uniform(3),
          heart_rate: 95 + :rand.uniform(15),
          respiratory_rate: 24 + :rand.uniform(4),
          temperature: Decimal.new("38.#{:rand.uniform(3)}"),
          systolic_bp: 95 + :rand.uniform(15),
          consciousness: "C",
          supplemental_o2: true
        }
    end
  end

  defp clamp(value, min, max) do
    value |> max(min) |> min(max)
  end
end
