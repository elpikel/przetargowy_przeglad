defmodule PrzetargowyPrzeglad.Reports.TenderReport do
  @moduledoc """
  Schema for tender reports.

  Reports can be of different types:
  - detailed: Specific region + order_type combination
  - region_summary: All order types for a specific region
  - industry_summary: All regions for a specific order type
  - overall: All tenders for the month
  """
  use Ecto.Schema

  import Ecto.Changeset

  schema "tender_reports" do
    field :title, :string
    field :slug, :string
    field :region, :string
    field :order_type, :string
    field :report_month, :date
    field :cover_image_url, :string
    field :report_type, :string
    field :report_data, :map
    field :introduction_html, :string
    field :analysis_html, :string
    field :upsell_html, :string
    field :graphs, :map
    field :meta_description, :string

    timestamps()
  end

  @valid_types ~w(detailed region_summary industry_summary overall)

  @doc """
  Changeset for creating or updating a tender report.
  """
  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :title,
      :slug,
      :region,
      :order_type,
      :report_month,
      :cover_image_url,
      :report_type,
      :report_data,
      :introduction_html,
      :analysis_html,
      :upsell_html,
      :graphs,
      :meta_description
    ])
    |> validate_required([
      :title,
      :slug,
      :report_month,
      :report_type,
      :report_data,
      :introduction_html,
      :analysis_html
    ])
    |> validate_inclusion(:report_type, @valid_types)
    |> validate_report_type_fields()
    |> unique_constraint(:slug)
  end

  # Validate that detailed reports have region and order_type
  defp validate_report_type_fields(changeset) do
    report_type = get_field(changeset, :report_type)

    case report_type do
      "detailed" ->
        validate_required(changeset, [:region, :order_type])

      "region_summary" ->
        validate_required(changeset, [:region])

      "industry_summary" ->
        validate_required(changeset, [:order_type])

      _ ->
        changeset
    end
  end
end
