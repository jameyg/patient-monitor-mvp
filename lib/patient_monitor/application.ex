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
      # Oban (background jobs)
      {Oban, Application.fetch_env!(:patient_monitor, Oban)},
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
end
