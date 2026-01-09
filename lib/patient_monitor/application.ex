defmodule PatientMonitor.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PatientMonitorWeb.Telemetry,
      PatientMonitor.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:patient_monitor, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:patient_monitor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PatientMonitor.PubSub},
      # Commanded application (event sourcing)
      PatientMonitor.Commanded.App,
      # Event handlers (must start after Commanded.App)
      PatientMonitor.Commanded.Handlers.ProjectionHandler,
      PatientMonitor.Commanded.Handlers.EscalationHandler,
      # Oban (background jobs)
      {Oban, Application.fetch_env!(:patient_monitor, Oban)},
      # Seeder task to register demo patients after everything starts
      {Task, fn -> seed_demo_patients() end},
      # Start to serve requests, typically the last entry
      PatientMonitorWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: PatientMonitor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PatientMonitorWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    System.get_env("RELEASE_NAME") == nil
  end

  defp seed_demo_patients do
    # Give the system a moment to fully start
    Process.sleep(500)

    alias PatientMonitor.Commanded.App
    alias PatientMonitor.Commanded.Commands.RegisterPatient

    patients = [
      %{patient_id: "P001", name: "John Smith", pathway_start_date: Date.add(Date.utc_today(), -7)},
      %{patient_id: "P002", name: "Jane Doe", pathway_start_date: Date.add(Date.utc_today(), -2)},
      %{patient_id: "P003", name: "Bob Wilson", pathway_start_date: Date.add(Date.utc_today(), -14)}
    ]

    for patient <- patients do
      command = %RegisterPatient{
        patient_id: patient.patient_id,
        name: patient.name,
        pathway_start_date: patient.pathway_start_date
      }

      case App.dispatch(command) do
        :ok -> :ok
        {:error, :patient_already_registered} -> :ok
        error -> error
      end
    end

    :ok
  end
end
