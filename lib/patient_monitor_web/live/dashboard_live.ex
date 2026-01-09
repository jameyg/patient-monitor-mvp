defmodule PatientMonitorWeb.DashboardLive do
  use PatientMonitorWeb, :live_view

  alias PatientMonitor.Patients
  alias PatientMonitor.Escalations
  alias PatientMonitor.Commanded.App
  alias PatientMonitor.Commanded.Commands.AcknowledgeAlert
  alias PatientMonitor.Workers.VitalsSimulator

  @pathway_steps [
    %{id: "enroll", label: "Enroll", day: 0},
    %{id: "device", label: "Device", day: 1},
    %{id: "welcome", label: "Welcome", day: 2},
    %{id: "monitor", label: "Monitor", day: 3},
    %{id: "review_7", label: "7-Day", day: 7},
    %{id: "review_14", label: "14-Day", day: 14},
    %{id: "review_21", label: "21-Day", day: 21},
    %{id: "discharge", label: "Discharge", day: 28}
  ]

  @escalation_steps [
    %{step: 1, name: "nurse", label: "Nurse Station", timeout: 30},
    %{step: 2, name: "senior_clinician", label: "Senior Clinician", timeout: 20},
    %{step: 3, name: "on_call_doctor", label: "On-Call Doctor", timeout: 15}
  ]

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Patients.subscribe()
      Escalations.subscribe()
      schedule_tick()
    end

    {:ok,
     socket
     |> assign(:patients, Patients.list_patients())
     |> assign(:escalations, Escalations.list_active_escalations())
     |> assign(:activity_log, Escalations.list_recent_activity(15))
     |> assign(:selected_patient, nil)
     |> assign(:user_name, "")
     |> assign(:pathway_steps, @pathway_steps)
     |> assign(:escalation_steps, @escalation_steps)
     |> assign(:show_info_card, true)
     |> assign(:current_time, DateTime.utc_now())
     |> assign(:show_audit_panel, false)
     |> assign(:audit_tab, "escalations")
     |> assign(:audit_data, nil)}
  end

  def handle_event("dismiss_info_card", _params, socket) do
    {:noreply, assign(socket, :show_info_card, false)}
  end

  def handle_event("simulate_vitals", _params, socket) do
    %{"action" => "simulate_all"}
    |> VitalsSimulator.new()
    |> Oban.insert()

    {:noreply, socket}
  end

  def handle_event("reset_demo", _params, socket) do
    PatientMonitor.Application.reset_demo()
    {:noreply, socket}
  end

  def handle_event("select_patient", %{"id" => id}, socket) do
    patient = Patients.get_patient_with_vitals(id)
    {:noreply, assign(socket, :selected_patient, patient)}
  end

  def handle_event("update_user_name", %{"value" => name}, socket) do
    {:noreply, assign(socket, :user_name, name)}
  end

  def handle_event("acknowledge_escalation", %{"escalation-id" => esc_id}, socket) do
    user_name = socket.assigns.user_name
    escalation = Escalations.get_escalation(esc_id)

    if user_name != "" and escalation do
      command = %AcknowledgeAlert{
        patient_id: escalation.patient_id,
        escalation_id: esc_id,
        acknowledged_by: user_name
      }

      App.dispatch(command)
    end

    {:noreply, socket}
  end

  def handle_event("toggle_audit_panel", _params, socket) do
    show = !socket.assigns.show_audit_panel
    socket = assign(socket, :show_audit_panel, show)

    socket =
      if show and socket.assigns.audit_data == nil do
        load_audit_data(socket, socket.assigns.audit_tab)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("switch_audit_tab", %{"tab" => tab}, socket) do
    {:noreply, socket |> assign(:audit_tab, tab) |> load_audit_data(tab)}
  end

  defp load_audit_data(socket, "escalations") do
    data = Escalations.list_all_escalations()
    assign(socket, :audit_data, data)
  end

  defp load_audit_data(socket, "steps") do
    data = Escalations.list_escalation_steps()
    assign(socket, :audit_data, data)
  end

  defp load_audit_data(socket, "vitals") do
    data = Patients.list_all_vitals()
    assign(socket, :audit_data, data)
  end

  defp load_audit_data(socket, "activity") do
    data = Escalations.list_all_activity()
    assign(socket, :audit_data, data)
  end

  defp load_audit_data(socket, "patients") do
    data = Patients.list_all_patients()
    assign(socket, :audit_data, data)
  end

  defp load_audit_data(socket, _), do: assign(socket, :audit_data, [])

  # PubSub handlers
  def handle_info({:patient_created, _patient}, socket) do
    {:noreply, assign(socket, :patients, Patients.list_patients())}
  end

  def handle_info({:patient_updated, _patient}, socket) do
    {:noreply, assign(socket, :patients, Patients.list_patients())}
  end

  def handle_info({:escalation_created, _escalation}, socket) do
    {:noreply,
     socket
     |> assign(:escalations, Escalations.list_active_escalations())
     |> assign(:activity_log, Escalations.list_recent_activity(15))}
  end

  def handle_info({:escalation_updated, _escalation}, socket) do
    {:noreply,
     socket
     |> assign(:escalations, Escalations.list_active_escalations())
     |> assign(:activity_log, Escalations.list_recent_activity(15))}
  end

  def handle_info({:activity_logged, _log}, socket) do
    {:noreply, assign(socket, :activity_log, Escalations.list_recent_activity(15))}
  end

  def handle_info(:demo_reset, socket) do
    {:noreply,
     socket
     |> assign(:patients, Patients.list_patients())
     |> assign(:escalations, Escalations.list_active_escalations())
     |> assign(:activity_log, Escalations.list_recent_activity(15))
     |> assign(:audit_data, nil)}
  end

  def handle_info(:tick, socket) do
    schedule_tick()
    {:noreply, assign(socket, :current_time, DateTime.utc_now())}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, 1_000)
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-100">
      <!-- Header -->
      <header class="bg-white shadow-sm border-b border-slate-200">
        <div class="max-w-7xl mx-auto px-4 py-4 flex justify-between items-center">
          <div>
            <h1 class="text-2xl font-bold text-slate-800">Patient Monitor</h1>
            <p class="text-sm text-slate-500">Commanded + Oban Demo</p>
          </div>
          <div class="flex gap-2">
            <button
              phx-click="simulate_vitals"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
            >
              Simulate Vitals
            </button>
            <button
              phx-click="reset_demo"
              data-confirm="Reset all demo data? This will clear all vitals, escalations, and activity."
              class="px-4 py-2 bg-slate-600 text-white rounded-lg hover:bg-slate-700 transition-colors font-medium"
            >
              Reset Demo
            </button>
          </div>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 py-6 space-y-6">
        <!-- Info Banner -->
        <.info_banner :if={@show_info_card} />
        
    <!-- Patient Cards -->
        <section>
          <h2 class="text-lg font-semibold text-slate-700 mb-3">Patients</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <.patient_card
              :for={patient <- @patients}
              patient={patient}
              pathway_steps={@pathway_steps}
            />
            <div
              :if={@patients == []}
              class="col-span-3 text-center py-12 text-slate-500 bg-white rounded-lg border border-dashed border-slate-300"
            >
              No patients registered. Run seeds to add demo patients.
            </div>
          </div>
        </section>
        
    <!-- Active Escalations -->
        <section :if={@escalations != []}>
          <h2 class="text-lg font-semibold text-slate-700 mb-3">Active Escalations</h2>
          <div class="space-y-4">
            <.escalation_panel
              :for={escalation <- @escalations}
              escalation={escalation}
              steps={@escalation_steps}
              current_time={@current_time}
              user_name={@user_name}
              patients={@patients}
            />
          </div>
        </section>
        
    <!-- Activity Log -->
        <section>
          <h2 class="text-lg font-semibold text-slate-700 mb-3">Activity Log</h2>
          <div class="bg-white rounded-lg shadow-sm border border-slate-200 p-4">
            <div class="space-y-2 max-h-64 overflow-y-auto">
              <.activity_entry :for={entry <- @activity_log} entry={entry} />
              <div :if={@activity_log == []} class="text-slate-500 text-sm text-center py-4">
                No activity yet. Simulate vitals to generate events.
              </div>
            </div>
          </div>
        </section>
        
    <!-- Audit Panel -->
        <section>
          <button
            phx-click="toggle_audit_panel"
            class="flex items-center gap-2 text-lg font-semibold text-slate-700 mb-3 hover:text-slate-900"
          >
            <svg
              class={"w-5 h-5 transition-transform #{if @show_audit_panel, do: "rotate-90", else: ""}"}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
            Audit Data (Raw)
          </button>

          <div :if={@show_audit_panel} class="bg-white rounded-lg shadow-sm border border-slate-200">
            <!-- Tabs -->
            <div class="flex border-b border-slate-200">
              <.audit_tab label="Escalations" tab="escalations" active={@audit_tab} />
              <.audit_tab label="Steps" tab="steps" active={@audit_tab} />
              <.audit_tab label="Vitals" tab="vitals" active={@audit_tab} />
              <.audit_tab label="Activity" tab="activity" active={@audit_tab} />
              <.audit_tab label="Patients" tab="patients" active={@audit_tab} />
            </div>
            
    <!-- Content -->
            <div class="p-4 max-h-96 overflow-auto">
              <.audit_table data={@audit_data} tab={@audit_tab} />
            </div>
          </div>
        </section>
      </main>
    </div>
    """
  end

  # Components

  defp info_banner(assigns) do
    ~H"""
    <div class="bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-xl p-5 relative">
      <button
        phx-click="dismiss_info_card"
        class="absolute top-3 right-3 text-slate-400 hover:text-slate-600 transition-colors"
        aria-label="Dismiss"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M6 18L18 6M6 6l12 12"
          />
        </svg>
      </button>
      <div class="flex gap-4">
        <div class="flex-shrink-0">
          <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
            <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>
        </div>
        <div class="flex-1 pr-8">
          <h3 class="font-semibold text-slate-900 mb-1">Event-Sourced Patient Monitoring Demo</h3>
          <p class="text-sm text-slate-600 mb-3">
            This demo showcases <strong>Commanded</strong>
            (event sourcing) + <strong>Oban</strong>
            (durable workflows) for clinical escalation. Vitals trigger NEWS2 alerts, which launch
            a timed escalation workflow that humans can acknowledge to cancel.
          </p>
          <div class="grid grid-cols-2 gap-4 mb-3">
            <div>
              <div class="text-xs font-semibold text-slate-700 mb-2">Try it out:</div>
              <ol class="text-xs text-slate-600 space-y-1 list-decimal list-inside">
                <li>Click <strong>Simulate Vitals</strong> to generate readings</li>
                <li>High NEWS2 scores trigger an <strong>escalation</strong></li>
                <li>Watch the 3-step workflow countdown (30s/20s/15s)</li>
                <li>Enter your name and <strong>Acknowledge</strong> to cancel</li>
              </ol>
            </div>
            <div>
              <div class="text-xs font-semibold text-slate-700 mb-2">See the event store:</div>
              <ol class="text-xs text-slate-600 space-y-1 list-decimal list-inside">
                <li>Click <strong>Show Audit Data</strong> to see raw tables</li>
                <li>View the immutable event history</li>
                <li>See how projections build read models</li>
                <li>Click <strong>Reset Demo</strong> to start fresh</li>
              </ol>
            </div>
          </div>
          <div class="flex flex-wrap gap-x-6 gap-y-2 text-xs pt-2 border-t border-blue-200">
            <div class="flex items-center gap-1.5 text-slate-500">
              <span class="font-medium text-slate-700">Tech:</span>
              <span>Commanded (Event Sourcing)</span>
              <span class="text-slate-300">•</span>
              <span>Oban (Workflows)</span>
              <span class="text-slate-300">•</span>
              <span>Phoenix LiveView</span>
              <span class="text-slate-300">•</span>
              <span>NEWS2 Scoring</span>
            </div>
            <div class="flex items-center gap-1.5 text-amber-600">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                />
              </svg>
              <span class="font-medium">Demo only:</span>
              <span>InMemory event store (not durable), SQLite, shortened timers</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp patient_card(assigns) do
    news2_class = news2_color_class(assigns.patient.latest_news2_score)
    pathway_day = calculate_pathway_day(assigns.patient)

    assigns =
      assigns
      |> assign(:news2_class, news2_class)
      |> assign(:pathway_day, pathway_day)

    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-slate-200 p-4 hover:shadow-md transition-shadow">
      <div class="flex justify-between items-start mb-3">
        <div>
          <h3 class="font-semibold text-slate-800">{@patient.patient_id}</h3>
          <p class="text-sm text-slate-500">{@patient.name}</p>
        </div>
        <div class={"px-2 py-1 rounded text-sm font-medium #{@news2_class}"}>
          NEWS2: {@patient.latest_news2_score || 0}
        </div>
      </div>
      
    <!-- Vitals Grid -->
      <div class="grid grid-cols-2 gap-2 text-sm mb-3">
        <div class="flex justify-between">
          <span class="text-slate-500">SpO2:</span>
          <span class={"font-medium #{if @patient.latest_spo2 && @patient.latest_spo2 < 92, do: "text-red-600", else: "text-slate-700"}"}>
            {(@patient.latest_spo2 && "#{@patient.latest_spo2}%") || "-"}
          </span>
        </div>
        <div class="flex justify-between">
          <span class="text-slate-500">HR:</span>
          <span class="font-medium text-slate-700">{@patient.latest_heart_rate || "-"}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-slate-500">RR:</span>
          <span class="font-medium text-slate-700">{@patient.latest_respiratory_rate || "-"}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-slate-500">BP:</span>
          <span class="font-medium text-slate-700">{@patient.latest_systolic_bp || "-"}</span>
        </div>
      </div>
      
    <!-- Pathway Progress -->
      <div class="border-t border-slate-100 pt-3">
        <div class="flex items-center justify-between text-xs text-slate-500 mb-1">
          <span>Pathway Day {@pathway_day}</span>
          <span>{pathway_stage(@pathway_day, @pathway_steps)}</span>
        </div>
        <div class="flex gap-1">
          <%= for step <- @pathway_steps do %>
            <div class={"h-2 flex-1 rounded-full #{if step.day <= @pathway_day, do: "bg-green-500", else: "bg-slate-200"}"} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp escalation_panel(assigns) do
    patient =
      Enum.find(assigns.patients, fn p -> p.patient_id == assigns.escalation.patient_id end)

    assigns = assign(assigns, :patient, patient)

    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-red-200 p-4">
      <div class="flex justify-between items-start mb-4">
        <div>
          <h3 class="font-semibold text-red-800">
            Escalation: {@escalation.patient_id}
            <span :if={@patient} class="font-normal text-slate-600">({@patient.name})</span>
          </h3>
          <p class="text-sm text-slate-500">
            Trigger: {format_trigger(@escalation.trigger_event)} (NEWS2: {@escalation.trigger_value})
          </p>
        </div>
        <span class={"px-2 py-1 rounded text-xs font-medium #{status_class(@escalation.status)}"}>
          {@escalation.status}
        </span>
      </div>
      
    <!-- DAG Visualization -->
      <div class="flex items-center justify-center gap-2 mb-4 py-4 bg-slate-50 rounded-lg">
        <%= for {step, idx} <- Enum.with_index(@steps) do %>
          <.step_node
            step={step}
            escalation={@escalation}
            current_time={@current_time}
          />
          <%= if idx < length(@steps) - 1 do %>
            <.step_connector
              from_step={step.step}
              current_step={@escalation.current_step}
            />
          <% end %>
        <% end %>
      </div>
      
    <!-- Acknowledge Form -->
      <div
        :if={@escalation.status == "active"}
        class="flex gap-2 items-center border-t border-slate-100 pt-4"
      >
        <input
          type="text"
          placeholder="Enter your name"
          value={@user_name}
          phx-keyup="update_user_name"
          class="flex-1 px-3 py-2 text-slate-900 bg-white border border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 placeholder:text-slate-400"
        />
        <button
          phx-click="acknowledge_escalation"
          phx-value-escalation-id={@escalation.id}
          disabled={@user_name == ""}
          class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-slate-300 disabled:cursor-not-allowed transition-colors font-medium text-sm"
        >
          Acknowledge
        </button>
      </div>
      
    <!-- Critical Alert for Unacknowledged -->
      <div :if={@escalation.status == "completed"} class="border-t border-red-200 pt-4 mt-2">
        <div class="bg-red-100 border border-red-300 rounded-lg p-3 flex items-center gap-3">
          <div class="flex-shrink-0">
            <svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
              />
            </svg>
          </div>
          <div>
            <p class="font-semibold text-red-800">CRITICAL: Escalation Unacknowledged</p>
            <p class="text-sm text-red-700">
              All escalation steps timed out without response. Immediate action required.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp step_node(assigns) do
    status = determine_step_status(assigns.step.step, assigns.escalation)

    time_remaining =
      calculate_time_remaining(assigns.step.step, assigns.escalation, assigns.current_time)

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:time_remaining, time_remaining)

    ~H"""
    <div class={"relative p-3 rounded-lg border-2 min-w-[120px] text-center transition-all #{step_node_classes(@status)}"}>
      <!-- Status indicator -->
      <div class={"absolute -top-2 -right-2 w-5 h-5 rounded-full flex items-center justify-center text-xs #{status_badge_classes(@status)}"}>
        <.status_icon status={@status} />
      </div>

      <div class="font-semibold text-sm mb-1 text-slate-800">{@step.label}</div>

      <%= case @status do %>
        <% :active -> %>
          <div class="text-xs text-amber-600 font-mono">
            {@time_remaining}s
          </div>
          <div class="mt-1 w-full bg-amber-200 rounded-full h-1">
            <div
              class="bg-amber-500 h-1 rounded-full transition-all"
              style={"width: #{time_progress_percent(@time_remaining, @step.timeout)}%"}
            />
          </div>
        <% :timeout -> %>
          <div class="text-xs text-red-600">Timeout</div>
        <% :pending -> %>
          <div class="text-xs text-slate-400">Waiting</div>
        <% :acknowledged -> %>
          <div class="text-xs text-green-600">Acknowledged</div>
        <% _ -> %>
          <div class="text-xs text-slate-400">-</div>
      <% end %>
    </div>
    """
  end

  defp step_connector(assigns) do
    passed = assigns.current_step > assigns.from_step
    assigns = assign(assigns, :passed, passed)

    ~H"""
    <div class="flex items-center">
      <div class={"w-6 h-0.5 #{if @passed, do: "bg-green-500", else: "bg-slate-300"}"} />
      <svg
        class={"w-3 h-3 #{if @passed, do: "text-green-500", else: "text-slate-300"}"}
        fill="currentColor"
        viewBox="0 0 20 20"
      >
        <path
          fill-rule="evenodd"
          d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
          clip-rule="evenodd"
        />
      </svg>
      <div class={"w-6 h-0.5 #{if @passed, do: "bg-green-500", else: "bg-slate-300"}"} />
    </div>
    """
  end

  defp status_icon(%{status: :active} = assigns), do: ~H|<span class="animate-pulse">!</span>|
  defp status_icon(%{status: :timeout} = assigns), do: ~H|<span>x</span>|
  defp status_icon(%{status: :pending} = assigns), do: ~H|<span>-</span>|
  defp status_icon(%{status: :acknowledged} = assigns), do: ~H|<span>v</span>|
  defp status_icon(assigns), do: ~H|<span>-</span>|

  defp activity_entry(assigns) do
    ~H"""
    <div class="flex items-start gap-3 text-sm py-2 border-b border-slate-100 last:border-0">
      <span class="text-slate-400 text-xs whitespace-nowrap">
        {Calendar.strftime(@entry.inserted_at, "%H:%M:%S")}
      </span>
      <span class={"w-2 h-2 rounded-full mt-1.5 #{action_color(@entry.action)}"} />
      <div class="flex-1">
        <span class="font-medium text-slate-700">{format_action(@entry.action)}</span>
        <span :if={@entry.patient_id} class="text-slate-500"> -           {@entry.patient_id}</span>
        <span :if={@entry.actor && @entry.actor != "System"} class="text-slate-400">
          by {@entry.actor}
        </span>
      </div>
    </div>
    """
  end

  # Helper functions

  defp news2_color_class(nil), do: "bg-slate-100 text-slate-600"
  defp news2_color_class(score) when score >= 7, do: "bg-red-100 text-red-700"
  defp news2_color_class(score) when score >= 5, do: "bg-orange-100 text-orange-700"
  defp news2_color_class(score) when score >= 1, do: "bg-yellow-100 text-yellow-700"
  defp news2_color_class(_), do: "bg-green-100 text-green-700"

  defp calculate_pathway_day(patient) do
    case patient.pathway_start_date do
      nil ->
        1

      start_date ->
        days = Date.diff(Date.utc_today(), start_date)
        max(1, min(days, 28))
    end
  end

  defp pathway_stage(day, steps) do
    steps
    |> Enum.filter(fn s -> s.day <= day end)
    |> List.last()
    |> case do
      nil -> "Enrolled"
      step -> step.label
    end
  end

  defp determine_step_status(step_num, escalation) do
    cond do
      escalation.status == "acknowledged" and escalation.current_step >= step_num -> :acknowledged
      step_num < escalation.current_step -> :timeout
      step_num == escalation.current_step -> :active
      true -> :pending
    end
  end

  defp calculate_time_remaining(step_num, escalation, current_time) do
    if step_num == escalation.current_step do
      deadline_field = String.to_atom("step#{step_num}_deadline")
      deadline = Map.get(escalation, deadline_field)

      if deadline do
        max(0, DateTime.diff(deadline, current_time))
      else
        0
      end
    else
      0
    end
  end

  defp time_progress_percent(remaining, total) do
    ((total - remaining) / total * 100) |> round() |> max(0) |> min(100)
  end

  defp step_node_classes(:active), do: "border-amber-400 bg-amber-50"
  defp step_node_classes(:timeout), do: "border-red-400 bg-red-50"
  defp step_node_classes(:pending), do: "border-slate-200 bg-white"
  defp step_node_classes(:acknowledged), do: "border-green-500 bg-green-50"
  defp step_node_classes(_), do: "border-slate-200 bg-white"

  defp status_badge_classes(:active), do: "bg-amber-500 text-white"
  defp status_badge_classes(:timeout), do: "bg-red-500 text-white"
  defp status_badge_classes(:pending), do: "bg-slate-300 text-slate-500"
  defp status_badge_classes(:acknowledged), do: "bg-green-600 text-white"
  defp status_badge_classes(_), do: "bg-slate-300 text-slate-500"

  defp status_class("active"), do: "bg-red-100 text-red-700"
  defp status_class("acknowledged"), do: "bg-green-100 text-green-700"
  defp status_class("completed"), do: "bg-red-200 text-red-800 font-semibold"
  defp status_class(_), do: "bg-slate-100 text-slate-700"

  defp format_trigger("spo2_critical"), do: "SpO2 Critical"
  defp format_trigger("hr_critical"), do: "Heart Rate Critical"
  defp format_trigger("news2_high"), do: "NEWS2 High"
  defp format_trigger("news2_medium"), do: "NEWS2 Medium"
  defp format_trigger(trigger), do: trigger

  defp format_action("escalation_started"), do: "Escalation started"
  defp format_action("escalation_acknowledged"), do: "Escalation acknowledged"
  defp format_action("escalation_completed"), do: "Escalation completed"
  defp format_action("step_started"), do: "Step started"
  defp format_action("step_completed"), do: "Step completed"
  defp format_action(action), do: action

  defp action_color("escalation_started"), do: "bg-red-500"
  defp action_color("escalation_acknowledged"), do: "bg-green-500"
  defp action_color("escalation_completed"), do: "bg-slate-500"
  defp action_color("step_started"), do: "bg-amber-500"
  defp action_color("step_completed"), do: "bg-blue-500"
  defp action_color(_), do: "bg-slate-400"

  # Audit components

  defp audit_tab(assigns) do
    ~H"""
    <button
      phx-click="switch_audit_tab"
      phx-value-tab={@tab}
      class={"px-4 py-2 text-sm font-medium border-b-2 #{if @active == @tab, do: "border-blue-500 text-blue-600", else: "border-transparent text-slate-500 hover:text-slate-700"}"}
    >
      {@label}
    </button>
    """
  end

  defp audit_table(%{data: nil} = assigns) do
    ~H"""
    <div class="text-center text-slate-500 py-8">Loading...</div>
    """
  end

  defp audit_table(%{data: []} = assigns) do
    ~H"""
    <div class="text-center text-slate-500 py-8">No data available</div>
    """
  end

  defp audit_table(%{tab: "escalations", data: data} = assigns) do
    assigns = assign(assigns, :rows, data)

    ~H"""
    <table class="w-full text-xs text-slate-700">
      <thead class="bg-slate-50 text-left">
        <tr>
          <th class="px-2 py-1 font-medium text-slate-600">ID</th>
          <th class="px-2 py-1 font-medium text-slate-600">Patient</th>
          <th class="px-2 py-1 font-medium text-slate-600">Trigger</th>
          <th class="px-2 py-1 font-medium text-slate-600">Value</th>
          <th class="px-2 py-1 font-medium text-slate-600">Status</th>
          <th class="px-2 py-1 font-medium text-slate-600">Step</th>
          <th class="px-2 py-1 font-medium text-slate-600">Ack By</th>
          <th class="px-2 py-1 font-medium text-slate-600">Started</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={row <- @rows} class="border-t border-slate-100">
          <td class="px-2 py-1 font-mono text-slate-500">{String.slice(row.id, 0..7)}</td>
          <td class="px-2 py-1">{row.patient_id}</td>
          <td class="px-2 py-1">{row.trigger_event}</td>
          <td class="px-2 py-1">{row.trigger_value}</td>
          <td class="px-2 py-1">
            <span class={"px-1 rounded #{status_badge_color(row.status)}"}>{row.status}</span>
          </td>
          <td class="px-2 py-1">{row.current_step}</td>
          <td class="px-2 py-1">{row.acknowledged_by || "-"}</td>
          <td class="px-2 py-1">{format_datetime(row.started_at)}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  defp audit_table(%{tab: "steps", data: data} = assigns) do
    assigns = assign(assigns, :rows, data)

    ~H"""
    <table class="w-full text-xs text-slate-700">
      <thead class="bg-slate-50 text-left">
        <tr>
          <th class="px-2 py-1 font-medium text-slate-600">Escalation</th>
          <th class="px-2 py-1 font-medium text-slate-600">Step #</th>
          <th class="px-2 py-1 font-medium text-slate-600">Type</th>
          <th class="px-2 py-1 font-medium text-slate-600">Status</th>
          <th class="px-2 py-1 font-medium text-slate-600">Outcome</th>
          <th class="px-2 py-1 font-medium text-slate-600">Notified</th>
          <th class="px-2 py-1 font-medium text-slate-600">Deadline</th>
          <th class="px-2 py-1 font-medium text-slate-600">Completed</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={row <- @rows} class="border-t border-slate-100">
          <td class="px-2 py-1 font-mono text-slate-500">{String.slice(row.escalation_id, 0..7)}</td>
          <td class="px-2 py-1">{row.step_number}</td>
          <td class="px-2 py-1">{row.step_type}</td>
          <td class="px-2 py-1">
            <span class={"px-1 rounded #{step_status_color(row.status)}"}>{row.status}</span>
          </td>
          <td class="px-2 py-1">{row.outcome || "-"}</td>
          <td class="px-2 py-1">{format_datetime(row.notified_at)}</td>
          <td class="px-2 py-1">{format_datetime(row.deadline)}</td>
          <td class="px-2 py-1">{format_datetime(row.completed_at)}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  defp audit_table(%{tab: "vitals", data: data} = assigns) do
    assigns = assign(assigns, :rows, data)

    ~H"""
    <table class="w-full text-xs text-slate-700">
      <thead class="bg-slate-50 text-left">
        <tr>
          <th class="px-2 py-1 font-medium text-slate-600">Patient</th>
          <th class="px-2 py-1 font-medium text-slate-600">SpO2</th>
          <th class="px-2 py-1 font-medium text-slate-600">HR</th>
          <th class="px-2 py-1 font-medium text-slate-600">RR</th>
          <th class="px-2 py-1 font-medium text-slate-600">Temp</th>
          <th class="px-2 py-1 font-medium text-slate-600">BP</th>
          <th class="px-2 py-1 font-medium text-slate-600">NEWS2</th>
          <th class="px-2 py-1 font-medium text-slate-600">Risk</th>
          <th class="px-2 py-1 font-medium text-slate-600">Recorded</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={row <- @rows} class="border-t border-slate-100">
          <td class="px-2 py-1">{row.patient_id}</td>
          <td class="px-2 py-1">{row.spo2}%</td>
          <td class="px-2 py-1">{row.heart_rate}</td>
          <td class="px-2 py-1">{row.respiratory_rate}</td>
          <td class="px-2 py-1">{row.temperature}</td>
          <td class="px-2 py-1">{row.systolic_bp}</td>
          <td class="px-2 py-1 font-medium">{row.news2_score}</td>
          <td class="px-2 py-1">
            <span class={"px-1 rounded #{risk_color(row.news2_risk_level)}"}>
              {row.news2_risk_level}
            </span>
          </td>
          <td class="px-2 py-1">{format_datetime(row.recorded_at)}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  defp audit_table(%{tab: "activity", data: data} = assigns) do
    assigns = assign(assigns, :rows, data)

    ~H"""
    <table class="w-full text-xs text-slate-700">
      <thead class="bg-slate-50 text-left">
        <tr>
          <th class="px-2 py-1 font-medium text-slate-600">Timestamp</th>
          <th class="px-2 py-1 font-medium text-slate-600">Patient</th>
          <th class="px-2 py-1 font-medium text-slate-600">Action</th>
          <th class="px-2 py-1 font-medium text-slate-600">Actor</th>
          <th class="px-2 py-1 font-medium text-slate-600">Details</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={row <- @rows} class="border-t border-slate-100">
          <td class="px-2 py-1">{format_datetime(row.inserted_at)}</td>
          <td class="px-2 py-1">{row.patient_id || "-"}</td>
          <td class="px-2 py-1">{row.action}</td>
          <td class="px-2 py-1">{row.actor}</td>
          <td class="px-2 py-1 font-mono text-slate-500">{Jason.encode!(row.details || %{})}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  defp audit_table(%{tab: "patients", data: data} = assigns) do
    assigns = assign(assigns, :rows, data)

    ~H"""
    <table class="w-full text-xs text-slate-700">
      <thead class="bg-slate-50 text-left">
        <tr>
          <th class="px-2 py-1 font-medium text-slate-600">Patient ID</th>
          <th class="px-2 py-1 font-medium text-slate-600">Name</th>
          <th class="px-2 py-1 font-medium text-slate-600">Status</th>
          <th class="px-2 py-1 font-medium text-slate-600">SpO2</th>
          <th class="px-2 py-1 font-medium text-slate-600">HR</th>
          <th class="px-2 py-1 font-medium text-slate-600">RR</th>
          <th class="px-2 py-1 font-medium text-slate-600">NEWS2</th>
          <th class="px-2 py-1 font-medium text-slate-600">Pathway Start</th>
          <th class="px-2 py-1 font-medium text-slate-600">Last Updated</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={row <- @rows} class="border-t border-slate-100">
          <td class="px-2 py-1 font-mono">{row.patient_id}</td>
          <td class="px-2 py-1">{row.name}</td>
          <td class="px-2 py-1">{row.status}</td>
          <td class="px-2 py-1">{row.latest_spo2 || "-"}</td>
          <td class="px-2 py-1">{row.latest_heart_rate || "-"}</td>
          <td class="px-2 py-1">{row.latest_respiratory_rate || "-"}</td>
          <td class="px-2 py-1">{row.latest_news2_score || "-"}</td>
          <td class="px-2 py-1">{row.pathway_start_date}</td>
          <td class="px-2 py-1">{format_datetime(row.vitals_updated_at)}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  defp audit_table(assigns) do
    ~H"""
    <div class="text-center text-slate-500 py-8">Select a tab to view data</div>
    """
  end

  # Audit helper functions

  defp format_datetime(nil), do: "-"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  defp status_badge_color("active"), do: "bg-red-100 text-red-700"
  defp status_badge_color("acknowledged"), do: "bg-green-100 text-green-700"
  defp status_badge_color("completed"), do: "bg-slate-100 text-slate-700"
  defp status_badge_color(_), do: "bg-slate-100 text-slate-600"

  defp step_status_color("active"), do: "bg-amber-100 text-amber-700"
  defp step_status_color("completed"), do: "bg-green-100 text-green-700"
  defp step_status_color("pending"), do: "bg-slate-100 text-slate-600"
  defp step_status_color(_), do: "bg-slate-100 text-slate-600"

  defp risk_color("low"), do: "bg-green-100 text-green-700"
  defp risk_color("low_medium"), do: "bg-yellow-100 text-yellow-700"
  defp risk_color("medium"), do: "bg-orange-100 text-orange-700"
  defp risk_color("high"), do: "bg-red-100 text-red-700"
  defp risk_color(_), do: "bg-slate-100 text-slate-600"
end
