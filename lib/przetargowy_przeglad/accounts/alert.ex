defmodule PrzetargowyPrzeglad.Accounts.Alert do
  @moduledoc """
  Schema for user alerts.
  Rules can be either:
  - Simple alert: %{region: "mazowieckie", industry: "it"}
  - Advanced alert: %{regions: ["mazowieckie", "malopolskie"], industries: ["it", "budownictwo"], keywords: ["oprogramowanie"]}
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
      industry: attrs["industry"] || attrs[:industry]
    })
    |> validate_required([:rules])
    |> validate_simple_rules()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_rules(changeset) do
    rules = get_field(changeset, :rules)

    case rules do
      %{region: _, industry: _} ->
        validate_simple_rules(changeset)

      %{regions: _, industries: _} ->
        validate_advanced_rules(changeset)

      _ ->
        add_error(changeset, :rules, "nieprawidłowy format reguł")
    end
  end

  defp validate_simple_rules(changeset) do
    rules = get_field(changeset, :rules)

    cond do
      is_nil(rules[:region]) && is_nil(rules["region"]) ->
        add_error(changeset, :rules, "region jest wymagany")

      is_nil(rules[:industry]) && is_nil(rules["industry"]) ->
        add_error(changeset, :rules, "industry jest wymagany")

      true ->
        changeset
    end
  end

  defp validate_advanced_rules(changeset) do
    rules = get_field(changeset, :rules)

    cond do
      not is_list(rules[:regions]) && not is_list(rules["regions"]) ->
        add_error(changeset, :rules, "regions musi być listą")

      not is_list(rules[:industries]) && not is_list(rules["industries"]) ->
        add_error(changeset, :rules, "industries musi być listą")

      true ->
        changeset
    end
  end
end
