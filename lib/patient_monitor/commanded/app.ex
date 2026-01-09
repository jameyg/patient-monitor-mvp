defmodule PatientMonitor.Commanded.App do
  @moduledoc """
  Commanded application for event sourcing.
  Uses InMemory event store for demo purposes.
  """
  use Commanded.Application,
    otp_app: :patient_monitor,
    event_store: [
      adapter: Commanded.EventStore.Adapters.InMemory
    ]

  router(PatientMonitor.Commanded.Router)
end
