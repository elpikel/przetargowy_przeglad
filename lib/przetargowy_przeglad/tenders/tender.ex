defmodule PrzetargowyPrzeglad.Tenders.Tender do
  use Ecto.Schema
  import Ecto.Changeset

  @sources ~w(bzp ted)
  @industries ~w(it budowlana medyczna transportowa uslugi dostawy inne)

  schema "tenders" do
    field :external_id, :string
    field :source, :string
    field :title, :string
    field :description, :string
    field :notice_type, :string

    field :contracting_authority_name, :string
    field :contracting_authority_city, :string
    field :contracting_authority_region, :string

    field :estimated_value, :decimal
    field :currency, :string, default: "PLN"
    field :submission_deadline, :utc_datetime
    field :publication_date, :utc_datetime

    field :cpv_codes, {:array, :string}, default: []
    field :industry, :string
    field :procedure_type, :string

    field :offers_count, :integer
    field :winning_price, :decimal
    field :winner_name, :string

    field :url, :string
    field :raw_data, :map
    field :fetched_at, :utc_datetime

    timestamps()
  end

  @required_fields ~w(external_id source title)a
  @optional_fields ~w(
       description notice_type
       contracting_authority_name contracting_authority_city contracting_authority_region
       estimated_value currency submission_deadline publication_date
       cpv_codes industry procedure_type
       offers_count winning_price winner_name
       url raw_data fetched_at
     )a

  def changeset(tender, attrs) do
    tender
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:source, @sources)
    |> validate_inclusion(:industry, @industries ++ [nil])
    |> unique_constraint([:external_id, :source])
    |> maybe_set_industry_from_cpv()
  end

  defp maybe_set_industry_from_cpv(changeset) do
    case get_change(changeset, :cpv_codes) do
      nil ->
        changeset

      [] ->
        changeset

      cpv_codes ->
        if get_change(changeset, :industry) == nil do
          put_change(changeset, :industry, map_cpv_to_industry(cpv_codes))
        else
          changeset
        end
    end
  end

  @doc """
  Maps CPV codes to industries.
  """
  def map_cpv_to_industry(cpv_codes) when is_list(cpv_codes) do
    cpv_codes
    |> Enum.find_value("inne", &cpv_to_industry/1)
  end

  defp cpv_to_industry(cpv) when is_binary(cpv) do
    cond do
      # IT services
      String.starts_with?(cpv, "72") -> "it"
      # Software
      String.starts_with?(cpv, "48") -> "it"
      # Office/computer equipment
      String.starts_with?(cpv, "30") -> "it"
      # Construction
      String.starts_with?(cpv, "45") -> "budowlana"
      # Architectural services
      String.starts_with?(cpv, "71") -> "budowlana"
      # Medical equipment
      String.starts_with?(cpv, "33") -> "medyczna"
      # Health services
      String.starts_with?(cpv, "85") -> "medyczna"
      # Transport
      String.starts_with?(cpv, "60") -> "transportowa"
      # Transport equipment
      String.starts_with?(cpv, "34") -> "transportowa"
      # Food
      String.starts_with?(cpv, "15") -> "dostawy"
      # Furniture
      String.starts_with?(cpv, "39") -> "dostawy"
      # Business services
      String.starts_with?(cpv, "79") -> "uslugi"
      # Sewage, refuse
      String.starts_with?(cpv, "90") -> "uslugi"
      true -> nil
    end
  end

  defp cpv_to_industry(_), do: nil

  def sources, do: @sources
  def industries, do: @industries
end
