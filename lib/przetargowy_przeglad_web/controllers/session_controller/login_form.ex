defmodule PrzetargowyPrzegladWeb.SessionController.LoginForm do
  @moduledoc """
  Embedded schema for login form validation.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :email, :string
    field :password, :string
  end

  @doc """
  Creates a changeset for login form validation.
  """
  def changeset(form \\ %__MODULE__{}, attrs) do
    form
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password], message: "to pole jest wymagane")
  end

  @doc """
  Adds an invalid credentials error to the changeset.
  """
  def add_credentials_error(changeset) do
    add_error(changeset, :email, "nieprawidłowy adres e-mail lub hasło")
  end
end
