defmodule PrzetargowyPrzeglad.Accounts.Alert do
  @moduledoc """
  Schema for user alerts.
  Rules can be either:
  - Simple alert: %{region: "mazowieckie", tender_category: "Dostawy"}
  - Advanced alert: %{regions: ["mazowieckie", "malopolskie"], tender_categories: ["Dostawy", "Usługi"], keywords: ["oprogramowanie"]}
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias PrzetargowyPrzeglad.Accounts.User

  schema "alerts" do
    field :rules, :map

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating an alert.
  """
  def changeset(alert \\ %__MODULE__{}, attrs) do
    alert
    |> cast(attrs, [:user_id, :rules])
    |> validate_required([:user_id, :rules])
    |> validate_rules()
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a simple alert for free plan users.
  """
  def simple_alert_changeset(alert \\ %__MODULE__{}, attrs) do
    alert
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
    |> put_change(:rules, %{
      region: attrs["region"] || attrs[:region],
      tender_category: attrs["tender_category"] || attrs[:tender_category]
    })
    |> validate_required([:rules])
    |> validate_simple_rules()
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a premium alert for paid plan users.
  Supports single selections that get converted to lists, plus a keyword.
  """
  def premium_alert_changeset(alert \\ %__MODULE__{}, attrs) do
    region = attrs["region"] || attrs[:region]
    keyword = attrs["keyword"] || attrs[:keyword]

    keywords =
      case keyword do
        nil -> []
        "" -> []
        kw -> [kw]
      end

    alert
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
    |> put_change(:rules, %{
      regions: if(region, do: [region], else: []),
      industries: [],
      keywords: keywords
    })
    |> validate_required([:rules])
    |> foreign_key_constraint(:user_id)
  end

  defp validate_rules(changeset) do
    rules = get_field(changeset, :rules)

    cond do
      # Simple alert format (free plan)
      match?(%{region: _, tender_category: _}, rules) ->
        validate_simple_rules(changeset)

      # Advanced alert format (legacy)
      match?(%{regions: _, tender_categories: _}, rules) ->
        validate_advanced_rules(changeset)

      # Premium alert format (industries, regions, keywords)
      match?(%{industries: _, regions: _, keywords: _}, rules) ->
        validate_premium_rules(changeset)

      # Also handle string keys for premium format
      is_map(rules) and
          (Map.has_key?(rules, "industries") or Map.has_key?(rules, :industries)) and
          (Map.has_key?(rules, "regions") or Map.has_key?(rules, :regions)) ->
        validate_premium_rules(changeset)

      true ->
        add_error(changeset, :rules, "nieprawidłowy format reguł")
    end
  end

  defp validate_premium_rules(changeset) do
    rules = get_field(changeset, :rules)
    industries = rules[:industries] || rules["industries"]
    regions = rules[:regions] || rules["regions"]
    keywords = rules[:keywords] || rules["keywords"]

    cond do
      not is_list(industries) ->
        add_error(changeset, :rules, "industries musi być listą")

      not is_list(regions) ->
        add_error(changeset, :rules, "regions musi być listą")

      not is_nil(keywords) and not is_list(keywords) ->
        add_error(changeset, :rules, "keywords musi być listą")

      true ->
        changeset
    end
  end

  defp validate_simple_rules(changeset) do
    rules = get_field(changeset, :rules)

    cond do
      is_nil(rules[:region]) && is_nil(rules["region"]) ->
        add_error(changeset, :rules, "region jest wymagany")

      is_nil(rules[:tender_category]) && is_nil(rules["tender_category"]) ->
        add_error(changeset, :rules, "rodzaj zamówienia jest wymagany")

      true ->
        changeset
    end
  end

  defp validate_advanced_rules(changeset) do
    rules = get_field(changeset, :rules)

    cond do
      not is_list(rules[:regions]) && not is_list(rules["regions"]) ->
        add_error(changeset, :rules, "regions musi być listą")

      not is_list(rules[:tender_categories]) && not is_list(rules["tender_categories"]) ->
        add_error(changeset, :rules, "tender_categories musi być listą")

      true ->
        changeset
    end
  end
end
