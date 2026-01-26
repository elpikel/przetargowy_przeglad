defmodule PrzetargowyPrzeglad.Workers.FetchTendersNoticesWorker do
  @moduledoc """
  Oban worker for fetching tenders notices from BZP API.
  Runs daily to fetch new and updated tenders notices.

  ## Arguments
  - `days` - Number of days back to fetch tenders notices from (defaults to 1)
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 3600]

  alias PrzetargowyPrzeglad.Bzp.Client, as: BZPClient
  alias PrzetargowyPrzeglad.Tenders
  alias PrzetargowyPrzeglad.Tenders.TenderNotice

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    days = args["days"] || 1

    publication_date_from = Date.utc_today() |> Date.add(-days) |> Date.to_iso8601()
    publication_date_to = Date.to_iso8601(Date.utc_today())

    Logger.info("Starting tender notices fetch from #{publication_date_from} to #{publication_date_to} (#{days} days)")

    Enum.reduce_while(TenderNotice.notice_types(), :ok, fn notice_type, _ ->
      Logger.info("Fetching tenders notices for notice type: #{notice_type}")

      case BZPClient.fetch_all_tender_notices(publication_date_from, publication_date_to, "TenderResultNotice") do
        {:ok, []} ->
          Logger.info("No new tenders notices found")
          {:cont, :ok}

        {:ok, tenders}
        when is_list(tenders) ->
          Logger.info("Fetched #{length(tenders)} tenders notices from BZP")

          {success_count, failed} = Tenders.upsert_tender_notices(tenders)

          if length(failed) > 0 do
            Logger.warning("Failed to upsert #{length(failed)} tenders notices")
          end

          Logger.info("Tender notices fetch complete. Inserted/Updated: #{success_count}, Failed: #{length(failed)}")

          {:cont, :ok}

        {:error, reason} ->
          Logger.error("Failed to fetch tenders notices: #{inspect(reason)}")
          {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Upserts all tender notices published between the given dates.
  publication_date_from = Date.utc_today() |> Date.shift(year: -2) |> Date.to_iso8601()
  publication_date_to = Date.to_iso8601(Date.utc_today())
  PrzetargowyPrzeglad.Workers.FetchTendersNoticesWorker.upsert_all_tender_notices(publication_date_from, publication_date_to)
  """
  def upsert_all_tender_notices(publication_date_from, publication_date_to) do
    for notice_type <- TenderNotice.notice_types() do
      Logger.info("Starting upsert for notice type: #{notice_type}")

      last_object_id = Tenders.get_last_object_id_by_notice_type(notice_type)
      upsert_all_tender_notices(last_object_id, publication_date_from, publication_date_to, notice_type)
    end
  end

  defp upsert_all_tender_notices(object_id, publication_date_from, publication_date_to, notice_type) do
    case BZPClient.fetch_tenders_notices(object_id, publication_date_from, publication_date_to, notice_type) do
      {:ok, %{tenders: []}} ->
        Logger.info("BZP API: No more results.")
        :ok

      {:ok, %{tenders: tenders}} ->
        Logger.info("BZP API: Got #{length(tenders)} tenders")
        # Rate limiting
        Process.sleep(200)

        {_success_count, failed} = Tenders.upsert_tender_notices(tenders)

        if length(failed) > 0 do
          raise "Failed to upsert #{length(failed)} tender notices"
        end

        last_tender = List.last(tenders)
        next_object_id = last_tender.object_id

        upsert_all_tender_notices(next_object_id, publication_date_from, publication_date_to, notice_type)

      {:error, reason} ->
        Logger.error("BZP API: Error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
