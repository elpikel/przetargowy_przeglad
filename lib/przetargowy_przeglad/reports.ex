defmodule PrzetargowyPrzeglad.Reports do
  @moduledoc """
  Context module for managing tender reports.
  """

  import Ecto.Query
  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Reports.TenderReport

  @doc """
  Lists tender reports with pagination.

  ## Options

    * `:page` - Page number (default: 1)
    * `:per_page` - Results per page (default: 12)

  ## Returns

  A map with:
    * `:reports` - List of reports
    * `:total_count` - Total number of reports
    * `:page` - Current page
    * `:per_page` - Results per page
    * `:total_pages` - Total number of pages

  ## Examples

      iex> list_tender_reports(page: 2, per_page: 10)
      %{reports: [...], total_count: 45, page: 2, per_page: 10, total_pages: 5}

  """
  def list_tender_reports(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 12)
    offset = (page - 1) * per_page

    base_query = from r in TenderReport

    total_count = base_query |> select([r], count(r.id)) |> Repo.one()

    reports =
      base_query
      |> order_by([r], [desc: r.report_month, asc: r.region, asc: r.order_type])
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    %{
      reports: reports,
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: ceil(total_count / per_page)
    }
  end

  @doc """
  Gets a tender report by slug.

  ## Examples

      iex> get_report_by_slug("mazowieckie-delivery-2026-01-01")
      %TenderReport{}

      iex> get_report_by_slug("nonexistent")
      nil

  """
  def get_report_by_slug(slug) when is_binary(slug) do
    Repo.get_by(TenderReport, slug: slug)
  end

  @doc """
  Gets a tender report by ID.

  ## Examples

      iex> get_report(123)
      %TenderReport{}

      iex> get_report(999)
      nil

  """
  def get_report(id) do
    Repo.get(TenderReport, id)
  end

  @doc """
  Creates or updates a tender report.

  Uses upsert logic based on the unique constraints:
  - For detailed reports: region + order_type + report_month
  - For summary reports: report_type + region/order_type + report_month

  ## Examples

      iex> upsert_report(%{title: "Report", slug: "report-slug", ...})
      {:ok, %TenderReport{}}

      iex> upsert_report(%{invalid: "data"})
      {:error, %Ecto.Changeset{}}

  """
  def upsert_report(attrs) do
    existing = find_existing_report(attrs)

    changeset =
      case existing do
        nil -> TenderReport.changeset(%TenderReport{}, attrs)
        report -> TenderReport.changeset(report, attrs)
      end

    Repo.insert_or_update(changeset)
  end

  @doc """
  Deletes a tender report.

  ## Examples

      iex> delete_report(report)
      {:ok, %TenderReport{}}

  """
  def delete_report(%TenderReport{} = report) do
    Repo.delete(report)
  end

  # Private Functions

  defp find_existing_report(%{report_type: "detailed"} = attrs) do
    Repo.get_by(TenderReport,
      region: attrs[:region],
      order_type: attrs[:order_type],
      report_month: attrs[:report_month],
      report_type: "detailed"
    )
  end

  defp find_existing_report(%{report_type: "region_summary"} = attrs) do
    from(r in TenderReport,
      where: r.region == ^attrs[:region],
      where: is_nil(r.order_type),
      where: r.report_month == ^attrs[:report_month],
      where: r.report_type == "region_summary"
    )
    |> Repo.one()
  end

  defp find_existing_report(%{report_type: "industry_summary"} = attrs) do
    from(r in TenderReport,
      where: is_nil(r.region),
      where: r.order_type == ^attrs[:order_type],
      where: r.report_month == ^attrs[:report_month],
      where: r.report_type == "industry_summary"
    )
    |> Repo.one()
  end

  defp find_existing_report(%{report_type: "overall"} = attrs) do
    from(r in TenderReport,
      where: is_nil(r.region),
      where: is_nil(r.order_type),
      where: r.report_month == ^attrs[:report_month],
      where: r.report_type == "overall"
    )
    |> Repo.one()
  end

  defp find_existing_report(_attrs), do: nil
end
