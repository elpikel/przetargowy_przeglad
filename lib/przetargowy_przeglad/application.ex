defmodule PrzetargowyPrzeglad.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PrzetargowyPrzegladWeb.Telemetry,
      PrzetargowyPrzeglad.Repo,
      {Oban, Application.fetch_env!(:przetargowy_przeglad, Oban)},
      {DNSCluster,
       query: Application.get_env(:przetargowy_przeglad, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PrzetargowyPrzeglad.PubSub},
      # Start a worker by calling: PrzetargowyPrzeglad.Worker.start_link(arg)
      # {PrzetargowyPrzeglad.Worker, arg},
      # Start to serve requests, typically the last entry
      PrzetargowyPrzegladWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PrzetargowyPrzeglad.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PrzetargowyPrzegladWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
