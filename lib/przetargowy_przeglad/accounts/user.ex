defmodule PrzetargowyPrzeglad.Accounts.User do
  @moduledoc """
  Schema for user accounts.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias PrzetargowyPrzeglad.Accounts.Alert

  @subscription_plans ["free", "paid"]

  schema "users" do
    field :email, :string
    field :password, :string
    field :subscription_plan, :string, default: "free"
    field :email_verified, :boolean, default: false
    field :email_verification_token, :string
    field :email_verification_sent_at, :utc_datetime

    has_many :alerts, Alert

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for user registration.
  Hashes the password and generates verification token before storing.
  """
  def registration_changeset(user \\ %__MODULE__{}, attrs) do
    user
    |> cast(attrs, [:email, :password, :subscription_plan])
    |> validate_required([:email, :password])
    |> validate_email()
    |> validate_password()
    |> validate_subscription_plan()
    |> hash_password()
    |> generate_verification_token()
  end

  @doc """
  Changeset for updating user data.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :subscription_plan])
    |> validate_required([:email])
    |> validate_email()
    |> validate_subscription_plan()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "nieprawidłowy format adresu e-mail")
    |> validate_length(:email, max: 160, message: "adres e-mail jest za długi")
    |> unsafe_validate_unique(:email, PrzetargowyPrzeglad.Repo, message: "ten adres e-mail jest już zarejestrowany")
    |> unique_constraint(:email, message: "ten adres e-mail jest już zarejestrowany")
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 8, message: "hasło musi mieć co najmniej 8 znaków")
    |> validate_length(:password, max: 80, message: "hasło jest za długie")
  end

  defp validate_subscription_plan(changeset) do
    validate_inclusion(changeset, :subscription_plan, @subscription_plans)
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        put_change(changeset, :password, Bcrypt.hash_pwd_salt(password))
    end
  end

  defp generate_verification_token(changeset) do
    token = generate_random_token()
    now = DateTime.truncate(DateTime.utc_now(), :second)

    changeset
    |> put_change(:email_verification_token, token)
    |> put_change(:email_verification_sent_at, now)
    |> put_change(:email_verified, false)
  end

  defp generate_random_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Verifies a password against a hashed password.
  """
  def verify_password(password, hashed_password) do
    Bcrypt.verify_pass(password, hashed_password)
  end

  @doc """
  Changeset for verifying user email.
  """
  def verify_email_changeset(user) do
    user
    |> change()
    |> put_change(:email_verified, true)
    |> put_change(:email_verification_token, nil)
  end

  @doc """
  Changeset for updating user password.
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password()
    |> hash_password()
  end

  @doc """
  Changeset for password change form with confirmation validation.
  Used for form validation before updating the password.
  """
  def password_change_changeset(attrs \\ %{}) do
    types = %{password: :string, password_confirmation: :string}

    {%{}, types}
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation],
      message: "pole jest wymagane"
    )
    |> validate_length(:password, min: 8, message: "hasło musi mieć co najmniej 8 znaków")
    |> validate_length(:password, max: 80, message: "hasło jest za długie")
    |> validate_confirmation(:password, message: "hasła nie są identyczne")
  end
end
