# Script for populating the database with demo patients.
#
# Run it with:
#     mix run priv/repo/seeds.exs

alias PatientMonitor.Commanded.App
alias PatientMonitor.Commanded.Commands.RegisterPatient

# Demo patients
patients = [
  %{patient_id: "P001", name: "John Smith", pathway_start_date: Date.add(Date.utc_today(), -7)},
  %{patient_id: "P002", name: "Jane Doe", pathway_start_date: Date.add(Date.utc_today(), -2)},
  %{patient_id: "P003", name: "Bob Wilson", pathway_start_date: Date.add(Date.utc_today(), -14)}
]

IO.puts("Registering demo patients...")

for patient <- patients do
  command = %RegisterPatient{
    patient_id: patient.patient_id,
    name: patient.name,
    pathway_start_date: patient.pathway_start_date
  }

  case App.dispatch(command) do
    :ok ->
      IO.puts("  Registered #{patient.patient_id}: #{patient.name}")

    {:error, :patient_already_registered} ->
      IO.puts("  #{patient.patient_id} already registered, skipping")

    {:error, reason} ->
      IO.puts("  Error registering #{patient.patient_id}: #{inspect(reason)}")
  end
end

IO.puts("\nDone! Start the server with: mix phx.server")
