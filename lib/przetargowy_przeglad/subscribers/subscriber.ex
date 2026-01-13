defmodule PrzetargowyPrzeglad.Subscribers.Subscriber do
  use Ecto.Schema
  import Ecto.Changeset

  @confirmed "confirmed"
  @pending "pending"
  @industries ~w(it budowlana medyczna transportowa uslugi dostawy inne)
  @statuses ~w(#{@pending} #{@confirmed} unsubscribed)

  schema "subscribers" do
    field :email, :string
    field :name, :string
    field :company_name, :string
    field :industry, :string
    field :regions, {:array, :string}, default: []
    field :status, :string, default: @pending
    field :confirmation_token, :string
    field :confirmed_at, :utc_datetime
    field :unsubscribed_at, :utc_datetime

    timestamps()
  end

  def signup_changeset(subscriber, attrs) do
    subscriber
    |> cast(attrs, [:email, :name, :company_name, :industry, :regions])
    |> validate_required([:email], message: "To pole jest wymagane.")
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "Niepoprawny format.")
    |> validate_inclusion(:industry, @industries ++ [nil])
    |> unique_constraint(:email, message: "Ten email jest już zarejestrowany.")
    |> put_confirmation_token()
  end

  def confirm_changeset(subscriber) do
    subscriber
    |> change()
    |> put_change(:status, "confirmed")
    |> put_change(:confirmed_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def unsubscribe_changeset(subscriber) do
    subscriber
    |> change()
    |> put_change(:status, "unsubscribed")
    |> put_change(:unsubscribed_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp put_confirmation_token(changeset) do
    if get_change(changeset, :email) do
      token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      put_change(changeset, :confirmation_token, token)
    else
      changeset
    end
  end

  def industries, do: @industries
  def statuses, do: @statuses
  def confirmed, do: @confirmed
  def pending, do: @pending
end
