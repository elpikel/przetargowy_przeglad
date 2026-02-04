defmodule PrzetargowyPrzeglad.Workers.GenerateMonthlyReports do
  @moduledoc """
  Oban worker that generates monthly tender reports.

  Runs on the 1st of each month at 2 AM to generate reports for the previous month.

  Generates four types of reports:
  1. Detailed reports - for each region+order_type combination with activity
  2. Region summaries - one per region with activity (all order types)
  3. Industry summaries - one per order type with activity (all regions)
  4. Overall summary - all tenders for the month
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 86400]

  import Ecto.Query
  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Tenders.TenderNotice
  alias PrzetargowyPrzeglad.Reports
  alias PrzetargowyPrzeglad.Reports.ReportGenerator

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Support manual month override for testing
    target_month =
      case args["month"] do
        nil ->
          # Previous month
          Date.utc_today() |> Date.beginning_of_month() |> Date.add(-1)

        month_string ->
          Date.from_iso8601!(month_string)
      end

    Logger.info("Generating tender reports for #{target_month}")

    # 1. Generate detailed reports for active combinations
    combinations = get_active_combinations(target_month)
    Logger.info("Found #{length(combinations)} active region+order_type combinations")

    Enum.each(combinations, fn {region, order_type} ->
      generate_detailed_report(target_month, region, order_type)
    end)

    # 2. Generate region summaries (one per region with activity)
    active_regions = combinations |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
    Logger.info("Generating #{length(active_regions)} region summary reports")

    Enum.each(active_regions, fn region ->
      generate_region_summary(target_month, region)
    end)

    # 3. Generate industry summaries (one per order type with activity)
    active_order_types = combinations |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
    Logger.info("Generating #{length(active_order_types)} industry summary reports")

    Enum.each(active_order_types, fn order_type ->
      generate_industry_summary(target_month, order_type)
    end)

    # 4. Generate overall summary (all tenders)
    generate_overall_summary(target_month)

    Logger.info("Successfully completed report generation for #{target_month}")
    :ok
  end

  # Private Functions

  defp get_active_combinations(month) do
    start_date = Date.beginning_of_month(month)
    end_date = Date.end_of_month(month)

    from(tn in TenderNotice,
      where: fragment("?::date", tn.publication_date) >= ^start_date,
      where: fragment("?::date", tn.publication_date) <= ^end_date,
      where: not is_nil(tn.organization_province),
      where: not is_nil(tn.order_type),
      select: {tn.organization_province, tn.order_type},
      distinct: true
    )
    |> Repo.all()
    |> Enum.map(fn {province_code, order_type} ->
      {province_to_region(province_code), order_type}
    end)
    |> Enum.filter(fn {region, _} -> region != nil end)
  end

  defp generate_detailed_report(month, region, order_type) do
    Logger.info("Generating detailed report for #{region} / #{order_type} / #{month}")

    tenders = fetch_tenders(month, region: region, order_type: order_type)

    if length(tenders) > 0 do
      report_attrs =
        ReportGenerator.generate(
          month: month,
          region: region,
          order_type: order_type,
          report_type: "detailed",
          tenders: tenders
        )

      case Reports.upsert_report(report_attrs) do
        {:ok, report} ->
          Logger.info("Successfully generated detailed report: #{report.slug}")

        {:error, changeset} ->
          Logger.error(
            "Failed to generate detailed report for #{region}/#{order_type}: #{inspect(changeset.errors)}"
          )
      end
    else
      Logger.info("Skipping detailed report for #{region}/#{order_type} - no tenders found")
    end
  end

  defp generate_region_summary(month, region) do
    Logger.info("Generating region summary for #{region} / #{month}")

    tenders = fetch_tenders(month, region: region)

    if length(tenders) > 0 do
      report_attrs =
        ReportGenerator.generate(
          month: month,
          region: region,
          order_type: nil,
          report_type: "region_summary",
          tenders: tenders
        )

      case Reports.upsert_report(report_attrs) do
        {:ok, report} ->
          Logger.info("Successfully generated region summary: #{report.slug}")

        {:error, changeset} ->
          Logger.error(
            "Failed to generate region summary for #{region}: #{inspect(changeset.errors)}"
          )
      end
    else
      Logger.info("Skipping region summary for #{region} - no tenders found")
    end
  end

  defp generate_industry_summary(month, order_type) do
    Logger.info("Generating industry summary for #{order_type} / #{month}")

    tenders = fetch_tenders(month, order_type: order_type)

    if length(tenders) > 0 do
      report_attrs =
        ReportGenerator.generate(
          month: month,
          region: nil,
          order_type: order_type,
          report_type: "industry_summary",
          tenders: tenders
        )

      case Reports.upsert_report(report_attrs) do
        {:ok, report} ->
          Logger.info("Successfully generated industry summary: #{report.slug}")

        {:error, changeset} ->
          Logger.error(
            "Failed to generate industry summary for #{order_type}: #{inspect(changeset.errors)}"
          )
      end
    else
      Logger.info("Skipping industry summary for #{order_type} - no tenders found")
    end
  end

  defp generate_overall_summary(month) do
    Logger.info("Generating overall summary for #{month}")

    tenders = fetch_tenders(month, [])

    if length(tenders) > 0 do
      report_attrs =
        ReportGenerator.generate(
          month: month,
          region: nil,
          order_type: nil,
          report_type: "overall",
          tenders: tenders
        )

      case Reports.upsert_report(report_attrs) do
        {:ok, report} ->
          Logger.info("Successfully generated overall summary: #{report.slug}")

        {:error, changeset} ->
          Logger.error("Failed to generate overall summary: #{inspect(changeset.errors)}")
      end
    else
      Logger.info("Skipping overall summary - no tenders found")
    end
  end

  defp fetch_tenders(month, filters) do
    start_date = Date.beginning_of_month(month) |> DateTime.new!(~T[00:00:00])
    end_date = Date.end_of_month(month) |> DateTime.new!(~T[23:59:59])

    query =
      from(tn in TenderNotice,
        where: tn.publication_date >= ^start_date,
        where: tn.publication_date <= ^end_date,
        where: not is_nil(tn.order_type),
        where: not is_nil(tn.organization_province)
      )

    query = apply_filters(query, filters)

    Repo.all(query)
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:region, region}, query ->
        province_code = region_to_province_code(region)
        where(query, [tn], tn.organization_province == ^province_code)

      {:order_type, order_type}, query ->
        where(query, [tn], tn.order_type == ^order_type)

      _, query ->
        query
    end)
  end

  # Province <-> Region Mapping

  defp province_to_region(province_code) do
    province_map = %{
      "PL02" => "dolnoslaskie",
      "PL04" => "kujawsko-pomorskie",
      "PL06" => "lubelskie",
      "PL08" => "lubuskie",
      "PL10" => "lodzkie",
      "PL12" => "malopolskie",
      "PL14" => "mazowieckie",
      "PL16" => "opolskie",
      "PL18" => "podkarpackie",
      "PL20" => "podlaskie",
      "PL22" => "pomorskie",
      "PL24" => "slaskie",
      "PL26" => "swietokrzyskie",
      "PL28" => "warminsko-mazurskie",
      "PL30" => "wielkopolskie",
      "PL32" => "zachodniopomorskie"
    }

    Map.get(province_map, province_code)
  end

  defp region_to_province_code(region) do
    region_map = %{
      "dolnoslaskie" => "PL02",
      "kujawsko-pomorskie" => "PL04",
      "lubelskie" => "PL06",
      "lubuskie" => "PL08",
      "lodzkie" => "PL10",
      "malopolskie" => "PL12",
      "mazowieckie" => "PL14",
      "opolskie" => "PL16",
      "podkarpackie" => "PL18",
      "podlaskie" => "PL20",
      "pomorskie" => "PL22",
      "slaskie" => "PL24",
      "swietokrzyskie" => "PL26",
      "warminsko-mazurskie" => "PL28",
      "wielkopolskie" => "PL30",
      "zachodniopomorskie" => "PL32"
    }

    Map.get(region_map, region)
  end
end
