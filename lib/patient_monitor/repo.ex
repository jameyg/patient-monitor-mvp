defmodule PatientMonitor.Repo do
  use Ecto.Repo,
    otp_app: :patient_monitor,
    adapter: Ecto.Adapters.SQLite3
end
