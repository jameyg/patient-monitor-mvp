# Patient Monitor

A demo application showcasing **Commanded** (event sourcing) + **Oban** (durable workflows) patterns for healthcare patient monitoring.

## Features

- **Event Sourcing** - Patient vitals recorded via Commanded aggregates
- **NEWS2 Calculation** - National Early Warning Score 2 from vital signs
- **Escalation Workflows** - 3-step DAG (Nurse 30s → Senior Clinician 20s → On-Call Doctor 15s)
- **Human-in-the-Loop** - Acknowledge alerts to cancel escalation
- **Real-time Updates** - LiveView with PubSub broadcasts

## Quick Start

```bash
# Clone and setup
cd patient_monitor
mix setup

# Start the server
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000)

## Demo Flow

1. **Patients** are pre-seeded with 3 demo patients at different pathway stages
2. Click **"Simulate Vitals"** to generate vital signs for all patients
3. If NEWS2 score >= 5 or critical vitals detected, an **escalation** is triggered
4. Watch the **escalation DAG** progress through steps with countdown timers
5. Enter your name and click **"Acknowledge"** to cancel the escalation

## Architecture

```
Simulated Vitals
      ↓
Commanded Aggregate (Patient)
  - Calculates NEWS2 score
  - Triggers AlertTriggered event when threshold crossed
      ↓
Event Handler → Creates escalation record + starts Oban workflow
      ↓
Oban Workflow (manual chaining)
  Step 1: Nurse Station (30s) → timeout →
  Step 2: Senior Clinician (20s) → timeout →
  Step 3: On-Call Doctor (15s)
      ↓
Human Acknowledgement → Cancels remaining steps
```

## Tech Stack

- **Phoenix 1.8** + LiveView
- **SQLite** (via ecto_sqlite3)
- **Commanded** (InMemory event store for demo)
- **Oban** (Lite engine for SQLite)
- **Tailwind CSS**

## Key Files

| File | Purpose |
|------|---------|
| `lib/patient_monitor/commanded/aggregates/patient.ex` | Patient aggregate with NEWS2 alerting |
| `lib/patient_monitor/workers/escalation_step_worker.ex` | Oban workflow with manual step chaining |
| `lib/patient_monitor/news2.ex` | NEWS2 score calculation |
| `lib/patient_monitor_web/live/dashboard_live.ex` | Main dashboard UI |

## Learn More

- [Commanded Documentation](https://hexdocs.pm/commanded)
- [Oban Documentation](https://hexdocs.pm/oban)
- [NEWS2 Clinical Guidance](https://www.rcplondon.ac.uk/projects/outputs/national-early-warning-score-news-2)
