defmodule FreeObanUi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FreeObanUiWeb.Telemetry,
      FreeObanUi.Repo,
      {DNSCluster, query: Application.get_env(:free_oban_ui, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FreeObanUi.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: FreeObanUi.Finch},
      # Start a worker by calling: FreeObanUi.Worker.start_link(arg)
      # {FreeObanUi.Worker, arg},
      # Start to serve requests, typically the last entry
      FreeObanUiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FreeObanUi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FreeObanUiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end