defmodule PrzetargowyPrzeglad.Tenders.Tender do
  @moduledoc """
  Schema for public procurement tenders.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @industries ~w(it budowlana medyczna transportowa uslugi dostawy inne)

  @cpv_to_industry %{
    "72" => "it",
    "48" => "it",
    "30" => "it",
    "45" => "budowlana",
    "71" => "budowlana",
    "33" => "medyczna",
    "85" => "medyczna",
    "60" => "transportowa",
    "34" => "transportowa",
    "79" => "uslugi",
    "90" => "uslugi",
    "15" => "dostawy",
    "39" => "dostawy"
  }

  schema "tenders" do
    field :external_id, :string
    field :source, :string, default: "bzp"
    field :title, :string
    field :description, :string
    field :contracting_authority_name, :string
    field :contracting_authority_city, :string
    field :contracting_authority_region, :string
    field :estimated_value, :decimal
    field :submission_deadline, :utc_datetime
    field :publication_date, :utc_datetime
    field :cpv_codes, {:array, :string}, default: []
    field :industry, :string
    field :procedure_type, :string
    field :offers_count, :integer
    field :winner_name, :string
    field :winner_value, :decimal
    field :url, :string
    field :raw_data, :map, default: %{}
    field :fetched_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(tender, attrs) do
    tender
    |> cast(attrs, [
      :external_id,
      :source,
      :title,
      :description,
      :contracting_authority_name,
      :contracting_authority_city,
      :contracting_authority_region,
      :estimated_value,
      :submission_deadline,
      :publication_date,
      :cpv_codes,
      :industry,
      :procedure_type,
      :offers_count,
      :winner_name,
      :winner_value,
      :url,
      :raw_data,
      :fetched_at
    ])
    |> validate_required([:external_id, :source, :title])
    |> unique_constraint([:external_id, :source])
    |> maybe_set_industry()
    |> maybe_set_fetched_at()
  end

  @doc """
  Infers industry from CPV codes.
  """
  def infer_industry_from_cpv([]), do: "inne"

  def infer_industry_from_cpv(cpv_codes) when is_list(cpv_codes) do
    Enum.find_value(cpv_codes, "inne", fn code ->
      prefix = String.slice(code || "", 0, 2)
      Map.get(@cpv_to_industry, prefix)
    end)
  end

  def infer_industry_from_cpv(_), do: "inne"

  @doc """
  Returns list of valid industries.
  """
  def industries, do: @industries

  @doc """
  Returns CPV to industry mapping.
  """
  def cpv_to_industry, do: @cpv_to_industry

  defp maybe_set_industry(changeset) do
    case get_change(changeset, :industry) do
      nil ->
        cpv_codes = get_field(changeset, :cpv_codes) || []
        industry = infer_industry_from_cpv(cpv_codes)
        put_change(changeset, :industry, industry)

      _ ->
        changeset
    end
  end

  defp maybe_set_fetched_at(changeset) do
    case get_field(changeset, :fetched_at) do
      nil -> put_change(changeset, :fetched_at, DateTime.truncate(DateTime.utc_now(), :second))
      _ -> changeset
    end
  end
end
