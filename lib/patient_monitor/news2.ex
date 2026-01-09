defmodule PatientMonitor.NEWS2 do
  @moduledoc """
  Calculates the National Early Warning Score 2 (NEWS2) from vital signs.

  Based on Royal College of Physicians guidance:
  https://www.rcplondon.ac.uk/projects/outputs/national-early-warning-score-news-2
  """

  @doc """
  Calculate NEWS2 score from vitals map.
  Returns {score, risk_level} tuple.
  """
  def calculate(vitals) do
    scores = [
      respiratory_rate_score(vitals[:respiratory_rate]),
      spo2_score(vitals[:spo2], vitals[:supplemental_o2]),
      systolic_bp_score(vitals[:systolic_bp]),
      heart_rate_score(vitals[:heart_rate]),
      consciousness_score(vitals[:consciousness]),
      temperature_score(vitals[:temperature])
    ]

    # Add 2 points if on supplemental oxygen
    oxygen_score = if vitals[:supplemental_o2], do: 2, else: 0

    total = Enum.sum(scores) + oxygen_score
    risk_level = determine_risk_level(total, scores)

    {total, risk_level}
  end

  # Respiratory rate scoring
  defp respiratory_rate_score(nil), do: 0
  defp respiratory_rate_score(rr) when rr <= 8, do: 3
  defp respiratory_rate_score(rr) when rr <= 11, do: 1
  defp respiratory_rate_score(rr) when rr <= 20, do: 0
  defp respiratory_rate_score(rr) when rr <= 24, do: 2
  defp respiratory_rate_score(_rr), do: 3

  # SpO2 scoring (Scale 1 - normal patients)
  defp spo2_score(nil, _), do: 0
  defp spo2_score(spo2, _) when spo2 <= 91, do: 3
  defp spo2_score(spo2, _) when spo2 <= 93, do: 2
  defp spo2_score(spo2, _) when spo2 <= 95, do: 1
  defp spo2_score(_spo2, _), do: 0

  # Systolic BP scoring
  defp systolic_bp_score(nil), do: 0
  defp systolic_bp_score(sbp) when sbp <= 90, do: 3
  defp systolic_bp_score(sbp) when sbp <= 100, do: 2
  defp systolic_bp_score(sbp) when sbp <= 110, do: 1
  defp systolic_bp_score(sbp) when sbp <= 219, do: 0
  defp systolic_bp_score(_sbp), do: 3

  # Heart rate scoring
  defp heart_rate_score(nil), do: 0
  defp heart_rate_score(hr) when hr <= 40, do: 3
  defp heart_rate_score(hr) when hr <= 50, do: 1
  defp heart_rate_score(hr) when hr <= 90, do: 0
  defp heart_rate_score(hr) when hr <= 110, do: 1
  defp heart_rate_score(hr) when hr <= 130, do: 2
  defp heart_rate_score(_hr), do: 3

  # Consciousness scoring (ACVPU scale)
  defp consciousness_score(nil), do: 0
  defp consciousness_score("A"), do: 0
  defp consciousness_score("C"), do: 3
  defp consciousness_score("V"), do: 3
  defp consciousness_score("P"), do: 3
  defp consciousness_score("U"), do: 3
  defp consciousness_score(_), do: 0

  # Temperature scoring
  defp temperature_score(nil), do: 0

  defp temperature_score(temp) when is_binary(temp) do
    case Decimal.parse(temp) do
      {decimal, _} -> temperature_score(decimal)
      :error -> 0
    end
  end

  defp temperature_score(%Decimal{} = temp) do
    temp_float = Decimal.to_float(temp)
    temperature_score_float(temp_float)
  end

  defp temperature_score(temp) when is_float(temp) or is_integer(temp) do
    temperature_score_float(temp)
  end

  defp temperature_score_float(temp) when temp <= 35.0, do: 3
  defp temperature_score_float(temp) when temp <= 36.0, do: 1
  defp temperature_score_float(temp) when temp <= 38.0, do: 0
  defp temperature_score_float(temp) when temp <= 39.0, do: 1
  defp temperature_score_float(_temp), do: 2

  # Risk level determination
  defp determine_risk_level(total, individual_scores) do
    max_individual = Enum.max(individual_scores)

    cond do
      total >= 7 -> "high"
      total >= 5 or max_individual == 3 -> "medium"
      total >= 1 -> "low_medium"
      true -> "low"
    end
  end
end
