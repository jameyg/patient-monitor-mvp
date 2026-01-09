# Patient Monitor

A Phoenix LiveView application demonstrating **event sourcing** (Commanded) and **durable workflows** (Oban) for clinical patient monitoring. Built as a demo to showcase how these patterns can enable robust, auditable healthcare workflows.

## Context

This prototype evaluates **Elixir/Phoenix + Commanded + Oban + SQLite** for event-sourced patient monitoring. The goal is to demonstrate:

- Event sourcing for immutable audit trails of all clinical data
- NEWS2 early warning score calculation from vital signs
- Automated escalation workflows with human-in-the-loop acknowledgement
- Real-time UI updates via LiveView and PubSub

This is a demo, not production code. It prioritizes clarity and demonstrating patterns over completeness.

## What's Included

### Core Workflow
1. **Patients are seeded** — 3 demo patients at different pathway stages
2. **Simulate Vitals** — Generates random vital signs, dispatched as Commanded events
3. **NEWS2 calculation** — Aggregate calculates National Early Warning Score 2
4. **Alert triggered** — Score >= 5 or critical vitals emit an AlertTriggered event
5. **Escalation workflow** — Event handler creates escalation + schedules Oban jobs
6. **Timed escalation** — 3-step DAG: Nurse (30s) → Senior (20s) → Doctor (15s)
7. **Human acknowledgement** — Enter name and acknowledge to cancel escalation

### Tech Stack
- **Phoenix 1.8** with LiveView for real-time UI
- **SQLite** via Ecto SQLite3 adapter (simple, no external DB needed)
- **Commanded** with InMemory event store (event sourcing)
- **Oban 2.18+** with `Oban.Engines.Lite` for background jobs
- **Tailwind CSS** for styling
- **PubSub** for real-time broadcast of changes

### Features
- Event-sourced patient vitals with full audit history
- NEWS2 clinical scoring (per Royal College of Physicians guidelines)
- Real-time escalation workflow with countdown timers
- Pathway progress visualization (Enroll → Device → Welcome → Monitor → Reviews)
- Activity log showing all events in real-time
- Audit data panel showing raw database tables
- Reset Demo button to clear all data and start fresh

## Running the Demo

```bash
cd patient_monitor

# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.setup

# Start the server
iex -S mix phx.server
```

Open [http://localhost:4000](http://localhost:4000)

## How to Demo

### Basic Workflow
1. Click **Simulate Vitals** to generate readings for all patients
2. Watch for high NEWS2 scores (orange/red badges)
3. If an escalation triggers, watch the 3-step countdown
4. Enter your name in the top-right field
5. Click **Acknowledge** to cancel the escalation
6. Check the Activity Log for real-time events

### See the Event Store
1. Click **Show Audit Data** to view raw database tables
2. See the immutable event history (vitals, alerts, acknowledgements)
3. Observe how projections build the read models
4. Click **Reset Demo** to clear everything and re-seed

### Escalation Times (Demo)
- Step 1 (Nurse Station): 30 seconds
- Step 2 (Senior Clinician): 20 seconds
- Step 3 (On-Call Doctor): 15 seconds

*In production these would be much longer (5-15 minutes per step).*

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PHOENIX LIVEVIEW                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │ Simulate Vitals │  │  Acknowledge    │  │      Real-time UI           │  │
│  │     Button      │  │     Button      │  │  (PubSub subscriptions)     │  │
│  └────────┬────────┘  └────────┬────────┘  └──────────────▲──────────────┘  │
└───────────┼─────────────────────┼──────────────────────────┼────────────────┘
            │                     │                          │
            ▼                     ▼                          │
┌─────────────────────────────────────────────────┐          │
│                 COMMANDED (Event Sourcing)      │          │
│  ┌───────────────────────────────────────────┐  │          │
│  │           Patient Aggregate               │  │          │
│  │  • Validates commands                     │  │          │
│  │  • Calculates NEWS2 score                 │  │          │
│  │  • Emits events (VitalsRecorded,          │  │          │
│  │    AlertTriggered, AlertAcknowledged)     │  │          │
│  └───────────────────┬───────────────────────┘  │          │
│                      │                          │          │
│                      ▼                          │          │
│  ┌───────────────────────────────────────────┐  │          │
│  │        InMemory Event Store               │  │          │
│  │  (PostgreSQL EventStore in production)    │  │          │
│  └───────────────────┬───────────────────────┘  │          │
│                      │                          │          │
│                      ▼                          │          │
│  ┌───────────────────────────────────────────┐  │          │
│  │           Event Handlers                  │  │          │
│  │  • ProjectionHandler → updates read DB    │──┼──────────┤
│  │  • EscalationHandler → starts workflows   │  │          │
│  └───────────────────┬───────────────────────┘  │          │
└──────────────────────┼──────────────────────────┘          │
                       │                                     │
                       ▼                                     │
┌─────────────────────────────────────────────────┐          │
│                  OBAN (Durable Jobs)            │          │
│  ┌───────────────────────────────────────────┐  │          │
│  │        EscalationStepWorker               │  │          │
│  │  • Step 1: Nurse (30s timeout)            │  │          │
│  │  • Step 2: Senior Clinician (20s)         │  │          │
│  │  • Step 3: On-Call Doctor (15s)           │  │          │
│  │  • Each step schedules the next on timeout│  │          │
│  └───────────────────┬───────────────────────┘  │          │
└──────────────────────┼──────────────────────────┘          │
                       │                                     │
                       ▼                                     │
┌─────────────────────────────────────────────────┐          │
│              SQLITE DATABASE (Ecto)             │          │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────┐  │          │
│  │   Patients   │ │  Escalations │ │  Oban   │  │          │
│  │ (projection) │ │   & Steps    │ │  Jobs   │  │          │
│  └──────────────┘ └──────────────┘ └─────────┘  │          │
│                          │                      │          │
│                          └──────────────────────┼──────────┘
│                            (broadcasts via PubSub)         │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow Summary

| Component | Responsibility | Storage |
|-----------|---------------|---------|
| **Commanded** | Event sourcing - immutable log of all domain events | InMemory (demo) / EventStore (prod) |
| **Oban** | Durable job scheduling - escalation step timeouts | SQLite `oban_jobs` table |
| **Ecto/SQLite** | Read models (projections) for fast queries | `patient_projections`, `escalations`, etc. |
| **PubSub** | Real-time UI updates | In-memory (Phoenix) |

## Project Structure

```
lib/
├── patient_monitor/
│   ├── application.ex              # App supervision tree + reset logic
│   ├── repo.ex                     # Ecto repo
│   ├── news2.ex                    # NEWS2 score calculation
│   ├── commanded/
│   │   ├── app.ex                  # Commanded application config
│   │   ├── router.ex               # Command routing
│   │   ├── aggregates/
│   │   │   └── patient.ex          # Patient aggregate with alerting
│   │   ├── commands/               # RegisterPatient, RecordVitals, etc.
│   │   ├── events/                 # PatientRegistered, VitalsRecorded, etc.
│   │   └── handlers/
│   │       ├── projection_handler.ex   # Updates read models
│   │       └── escalation_handler.ex   # Creates escalations
│   ├── patients/
│   │   ├── patients.ex             # Patient context
│   │   ├── patient_projection.ex   # Read model schema
│   │   └── vitals_reading.ex       # Vitals history schema
│   ├── escalations/
│   │   ├── escalations.ex          # Escalation context
│   │   ├── escalation.ex           # Escalation schema
│   │   └── escalation_step.ex      # Step schema
│   └── workers/
│       ├── escalation_step_worker.ex   # Oban job for step timeouts
│       └── vitals_simulator.ex         # Oban job for vitals simulation
├── patient_monitor_web/
│   ├── live/
│   │   └── dashboard_live.ex       # Main LiveView (all UI logic)
│   └── router.ex                   # Routes "/" to DashboardLive
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/patient_monitor/commanded/aggregates/patient.ex` | Patient aggregate with NEWS2 alerting |
| `lib/patient_monitor/workers/escalation_step_worker.ex` | Oban workflow with manual step chaining |
| `lib/patient_monitor/news2.ex` | NEWS2 score calculation |
| `lib/patient_monitor_web/live/dashboard_live.ex` | Main dashboard UI |

## What's NOT Included (Out of Scope for Demo)

- User authentication (just a name input)
- Durable event store (uses InMemory, lost on restart)
- Real patient data or EHR integration
- Communications (SMS, email, pager)
- Multi-tenancy
- Production error handling
- Tests

## Production Considerations

If moving this pattern to production, you would need:

### Event Store Durability
- Replace `Commanded.EventStore.Adapters.InMemory` with [EventStore](https://github.com/commanded/eventstore) (PostgreSQL-backed)
- Events become truly immutable and survive restarts
- Enables event replay, projections rebuild, and full audit history

### Database
- Replace SQLite with PostgreSQL
- Use full Oban engine (not Lite) for multi-node support
- Add proper indexing for query performance

### Escalation Timers
- Increase from 30s/20s/15s to realistic clinical timeframes (5-15 minutes)
- Add configurable SLA policies per urgency level

### Notifications
- Integrate SMS, email, or pager for escalation steps
- Connect to hospital communication systems

### Security & Compliance
- Add authentication (OAuth, SAML for healthcare SSO)
- Implement RBAC for different clinical roles
- Ensure HIPAA/GDPR compliance for audit logs
- Add encryption at rest and in transit

### Monitoring
- Add Oban Web for job monitoring
- Implement health checks and alerting
- Add telemetry and observability

## Learn More

- [Commanded Documentation](https://hexdocs.pm/commanded)
- [EventStore (Durable Store)](https://hexdocs.pm/eventstore)
- [Oban Documentation](https://hexdocs.pm/oban)
- [NEWS2 Clinical Guidance](https://www.rcplondon.ac.uk/projects/outputs/national-early-warning-score-news-2)
