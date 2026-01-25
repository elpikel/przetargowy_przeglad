defmodule PrzetargowyPrzeglad.Workers.FetchTendersWorker do
  @moduledoc """
  Oban worker for fetching tenders from BZP API.
  Runs daily to fetch new and updated tenders.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 3600]

  alias PrzetargowyPrzeglad.Bzp.Client, as: BZPClient
  alias PrzetargowyPrzeglad.Tenders

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    days_back = args["days_back"] || 1

    Logger.info("Starting tender fetch for last #{days_back} day(s)")

    case BZPClient.fetch_tenders(days_back: days_back) do
      {:ok,
       %{
         tenders: tenders,
         total: _total,
         page: _page
       }}
      when is_list(tenders) ->
        Logger.info("Fetched #{length(tenders)} tenders from BZP")

        {success_count, failed} = Tenders.upsert_tenders(tenders)

        if length(failed) > 0 do
          Logger.warning("Failed to upsert #{length(failed)} tenders")
        end

        Logger.info("Tender fetch complete. Inserted/Updated: #{success_count}, Failed: #{length(failed)}")

        {:ok, %{fetched: length(tenders), inserted: success_count, failed: length(failed)}}

      {:ok, []} ->
        Logger.info("No new tenders found")
        {:ok, %{fetched: 0, inserted: 0, failed: 0}}

      {:error, reason} ->
        Logger.error("Failed to fetch tenders: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
