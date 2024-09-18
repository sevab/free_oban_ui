defmodule FreeObanUiWeb.ObanLive.Index do
  use FreeObanUiWeb, :live_view
  alias FreeObanUi.Repo
  import Ecto.Query

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(2000, self(), :update)
    end

    {:ok,
     socket
     |> assign(
       jobs: [],
       job: nil,
       selected_jobs: MapSet.new(),
       auto_refresh: true,
       page: params["page"] || "0"
     )
     |> assign_params(params)
     |> assign_counts()
     |> fetch_jobs()}
  end

  defp assign_params(socket, params) do
    socket
    |> assign(
      state: params["state"],
      queue: params["queue"],
      id: params["id"],
      page: params["page"] || "0"
    )
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> assign_params(params)
     |> fetch_jobs()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Oban Jobs")
    |> assign(:job, nil)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    job = get_job(id)

    socket
    |> assign(:page_title, "Job #{job.id}")
    |> assign(:job, get_job(id))
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    action_job("delete", id)

    {:noreply,
     socket
     |> put_flash(:info, "Job ##{id} deleted")
     |> redirect_back()}
  end

  defp action_job(action, id) do
    case action do
      # Same implementation as `retry` atm.
      # Alt: is to overwrite `scheduled_at` timestamp: https://elixirforum.com/t/53920/2
      "run" -> get_job(id) |> Oban.retry_job()
      "retry" -> get_job(id) |> Oban.retry_job()
      "cancel" -> get_job(id) |> Oban.cancel_job()
      "delete" -> get_job(id) |> Repo.delete()
    end
  end

  @impl true
  def handle_event("execute_action", %{"action" => action}, socket) do
    id = socket.assigns.job.id
    action_job(action, id)

    socket =
      if action == "delete" do
        socket
        |> put_flash(:info, "Job ##{id} deleted")
        |> redirect_back()
      else
        fetch_jobs(socket)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("bulk_action", %{"action" => action}, socket) do
    Enum.each(socket.assigns.selected_jobs, fn id ->
      action_job(action, id)
    end)

    {:noreply, socket |> assign(selected_jobs: MapSet.new()) |> fetch_jobs()}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/oban?#{[queue: socket.assigns.queue, state: socket.assigns.state, page: page]}"
     )}
  end

  @impl true
  def handle_event("toggle_refresh", _, socket) do
    {:noreply, assign(socket, auto_refresh: !socket.assigns.auto_refresh)}
  end

  @impl true
  def handle_info(:update, %{assigns: %{auto_refresh: true}} = socket) do
    {:noreply, fetch_jobs(socket)}
  end

  @impl true
  def handle_info(:update, socket), do: {:noreply, socket}

  def available_actions(state) do
    case state do
      "executing" -> ~w(cancel)
      "scheduled" -> ~w(run cancel delete)
      "retryable" -> ~w(retry cancel delete)
      "cancelled" -> ~w(retry delete)
      "discarded" -> ~w(retry delete)
      "complete" -> ~w(retry delete)
      _ -> ~w(delete)
    end
  end

  def back_url(assigns) do
    ~p"/oban?#{[queue: assigns.queue, state: assigns.state, page: assigns.page]}"
  end

  defp redirect_back(socket) do
    push_patch(socket, to: back_url(socket.assigns))
  end

  defp job_stats(job) do
    [
      %{title: "State", value: job.state},
      %{title: "Queue", value: job.queue},
      %{title: "Worker", value: job.worker},
      %{title: "Inserted At", value: job.inserted_at},
      %{title: "Scheduled At", value: job.scheduled_at},
      %{title: "Discarded At", value: job.discarded_at},
      %{title: "Cancelled At", value: job.cancelled_at},
      %{title: "Attempted At", value: job.attempted_at},
      %{title: "Completed At", value: job.completed_at},
      %{title: "Attempt", value: "#{job.attempt} of #{job.max_attempts}"}
    ]
  end

  defp assign_counts(socket) do
    counts =
      Oban.Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Enum.into(%{})

    queues =
      Oban.Job
      |> group_by([j], j.queue)
      |> select([j], {j.queue, count(j.id)})
      |> Repo.all()
      |> Enum.into(%{})

    assign(socket, counts: counts, queues: queues)
  end

  defp fetch_jobs(socket) do
    # Fetch & refresh `jobs` for :index, and `job` for :show
    if socket.assigns.live_action == :index do
      jobs =
        Oban.Job
        |> filter_by_state(socket.assigns.state)
        |> filter_by_queue(socket.assigns.queue)
        |> order_by([j], desc: j.inserted_at)
        |> paginate(socket.assigns.page)
        |> Repo.all()

      assign(socket, jobs: jobs)
    else
      assign(socket, jobs: [], job: get_job(socket.assigns.id))
    end
  end

  defp paginate(query, page) when page in [nil, ""], do: query

  defp paginate(query, page) do
    per_page = 25
    page = String.to_integer(page)
    offset_by = per_page * page

    query
    |> limit(^per_page)
    |> offset(^offset_by)
  end

  defp get_job(id) when id in [nil, ""], do: nil
  defp get_job(id), do: Oban.Job |> Repo.get!(id)

  defp filter_by_state(query, state) when state in [nil, ""], do: query
  defp filter_by_state(query, state), do: where(query, [j], j.state == ^state)

  defp filter_by_queue(query, queue) when queue in [nil, ""], do: query
  defp filter_by_queue(query, queue), do: where(query, [j], j.queue == ^queue)

  def from_now_short(now \\ DateTime.utc_now(), later) do
    diff = DateTime.diff(now, later)

    cond do
      diff <= -24 * 3600 -> "in #{div(-diff, 24 * 3600)}d"
      diff <= -3600 -> "in #{div(-diff, 3600)}h"
      diff <= -60 -> "in #{div(-diff, 60)}m"
      diff <= -5 -> "in #{-diff}s"
      diff <= 5 -> "now"
      diff <= 60 -> "#{diff}s ago"
      diff <= 3600 -> "#{div(diff, 60)} minutes ago"
      diff <= 24 * 3600 -> "#{div(diff, 3600)}m ago"
      true -> "#{div(diff, 24 * 3600)}d ago"
    end
  end
end
