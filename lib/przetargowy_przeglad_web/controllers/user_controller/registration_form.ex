defmodule PrzetargowyPrzegladWeb.UserController.RegistrationForm do
  @moduledoc """
  Embedded schema for user registration form.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :email, :string
    field :password, :string
    field :password_confirmation, :string
    field :terms, :boolean, default: false
  end

  @required_fields [:email, :password, :password_confirmation, :terms]

  @doc """
  Creates a changeset for registration form validation.
  """
  def changeset(form \\ %__MODULE__{}, attrs) do
    form
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields, message: "to pole jest wymagane")
    |> validate_email()
    |> validate_password()
    |> validate_password_confirmation()
    |> validate_terms()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "nieprawidłowy format adresu e-mail")
    |> validate_length(:email, max: 160, message: "adres e-mail jest za długi")
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 8, message: "hasło musi mieć co najmniej 8 znaków")
    |> validate_length(:password, max: 80, message: "hasło jest za długie")
  end

  defp validate_password_confirmation(changeset) do
    password = get_field(changeset, :password)
    password_confirmation = get_field(changeset, :password_confirmation)

    if password && password_confirmation && password != password_confirmation do
      add_error(changeset, :password_confirmation, "hasła nie są identyczne")
    else
      changeset
    end
  end

  defp validate_terms(changeset) do
    if get_field(changeset, :terms) do
      changeset
    else
      add_error(changeset, :terms, "musisz zaakceptować regulamin")
    end
  end
end
