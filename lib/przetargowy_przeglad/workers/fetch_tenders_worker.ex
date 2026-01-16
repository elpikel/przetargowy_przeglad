defmodule PrzetargowyPrzeglad.Workers.FetchTendersWorker do
  @moduledoc """
  Oban worker for periodically fetching tenders from BZP.

  Runs hourly via the Oban Cron plugin.
  """

  use Oban.Worker,
    queue: :tenders,
    max_attempts: 3,
    priority: 1

  alias PrzetargowyPrzeglad.Api.BzpClient
  alias PrzetargowyPrzeglad.Tenders

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Default to last 24h
    days = args["days"] || 1
    max_pages = args["max_pages"] || 5

    Logger.info("FetchTendersWorker: Starting fetch for last #{days} day(s)")

    case BzpClient.fetch_recent(days, max_pages: max_pages) do
      {:ok, tenders} ->
        result = Tenders.upsert_tenders(tenders)

        Logger.info("""
        FetchTendersWorker: Completed
          Fetched: #{length(tenders)}
          Inserted/Updated: #{result.inserted}
          Failed: #{result.failed}
        """)

        if result.failed > 0 do
          Logger.warning(
            "FetchTendersWorker: #{result.failed} failures: #{inspect(result.errors)}"
          )
        end

        :ok

      {:error, reason} ->
        Logger.error("FetchTendersWorker: Failed - #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Manually enqueue the worker.
  """
  def enqueue(opts \\ []) do
    args = %{
      "days" => opts[:days] || 1,
      "max_pages" => opts[:max_pages] || 5
    }

    args
    |> new()
    |> Oban.insert()
  end

  @doc """
  Full fetch (e.g., for initial run).
  """
  def enqueue_full_fetch(days \\ 30) do
    enqueue(days: days, max_pages: 50)
  end
end
