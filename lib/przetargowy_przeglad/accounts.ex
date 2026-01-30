defmodule PrzetargowyPrzeglad.Accounts do
  @moduledoc """
  Context module for managing user accounts and alerts.
  """

  import Ecto.Query

  alias PrzetargowyPrzeglad.Accounts.Alert
  alias PrzetargowyPrzeglad.Accounts.User
  alias PrzetargowyPrzeglad.Accounts.UserVerificationEmail
  alias PrzetargowyPrzeglad.Mailer
  alias PrzetargowyPrzeglad.Repo

  require Logger

  # User functions

  @doc """
  Gets a single user by ID.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a single user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email, email_verified: true)
  end

  @doc """
  Gets a single user by email.
  """
  def get_non_verified_user_by_email(email) do
    Repo.get_by(User, email: email, email_verified: false)
  end

  @doc """
  Registers a new user with a simple alert.

  ## Examples

      iex> register_user(%{email: "user@example.com", password: "password123", tender_category: "Dostawy", region: "mazowieckie"})
      {:ok, %{user: %User{}, alert: %Alert{}}}

      iex> register_user(%{email: "invalid", password: "short"})
      {:error, :user, %Ecto.Changeset{}, %{}}
  """
  def register_user(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:user, User.registration_changeset(%User{}, attrs))
    |> Ecto.Multi.insert(:alert, fn %{user: user} ->
      # Ensure consistent key type (string or atom) to avoid mixed keys error
      alert_attrs =
        if is_map(attrs) and Map.has_key?(attrs, "email") do
          Map.put(attrs, "user_id", user.id)
        else
          Map.put(attrs, :user_id, user.id)
        end

      Alert.simple_alert_changeset(%Alert{}, alert_attrs)
    end)
    |> Ecto.Multi.run(:send_email, fn _repo, %{user: user} ->
      send_verification_email(user)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, alert: alert}} ->
        {:ok, %{user: user, alert: alert}}

      {:error, :user, changeset, _} ->
        {:error, :user, changeset, %{}}

      {:error, :alert, changeset, _} ->
        {:error, :alert, changeset, %{}}

      {:error, :send_email, reason, _} ->
        Logger.error("Failed to send verification email: #{inspect(reason)}")
        # Email failure shouldn't prevent registration
        # We can retry sending later or user can request a new email
        {:error, :send_email, reason, %{}}
    end
  end

  @doc """
  Registers a new premium user with a premium alert.

  ## Examples

      iex> register_premium_user(%{email: "user@example.com", password: "password123", region: "mazowieckie", keyword: "software"})
      {:ok, %{user: %User{subscription_plan: "paid"}, alert: %Alert{}}}
  """
  def register_premium_user(attrs) do
    # Add subscription_plan to attrs
    user_attrs =
      if is_map(attrs) and Map.has_key?(attrs, "email") do
        Map.put(attrs, "subscription_plan", "paid")
      else
        Map.put(attrs, :subscription_plan, "paid")
      end

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:user, User.registration_changeset(%User{}, user_attrs))
    |> Ecto.Multi.insert(:alert, fn %{user: user} ->
      alert_attrs =
        if is_map(attrs) and Map.has_key?(attrs, "email") do
          Map.put(attrs, "user_id", user.id)
        else
          Map.put(attrs, :user_id, user.id)
        end

      Alert.premium_alert_changeset(%Alert{}, alert_attrs)
    end)
    |> Ecto.Multi.run(:send_email, fn _repo, %{user: user} ->
      send_verification_email(user)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, alert: alert}} ->
        {:ok, %{user: user, alert: alert}}

      {:error, :user, changeset, _} ->
        {:error, :user, changeset, %{}}

      {:error, :alert, changeset, _} ->
        {:error, :alert, changeset, %{}}

      {:error, :send_email, reason, _} ->
        Logger.error("Failed to send verification email: #{inspect(reason)}")
        {:error, :send_email, reason, %{}}
    end
  end

  defp send_verification_email(user) do
    verification_url = build_verification_url(user.email_verification_token)

    case user |> UserVerificationEmail.compose(verification_url) |> Mailer.deliver() do
      {:ok, _metadata} ->
        Logger.info("Verification email sent to #{user.email}")
        {:ok, :email_sent}

      {:error, reason} ->
        Logger.error("Failed to send verification email to #{user.email}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_verification_url(token) do
    # In production, this should use the actual domain
    # For now, we'll use a relative path that will be handled by the router
    PrzetargowyPrzegladWeb.Endpoint.url() <> "/verify-email?token=#{token}"
  end

  @doc """
  Authenticates a user by email and password.

  ## Examples

      iex> authenticate_user("user@example.com", "password123")
      {:ok, %User{}}

      iex> authenticate_user("user@example.com", "wrong_password")
      {:error, :invalid_credentials}
  """
  def authenticate_user(email, password) do
    case get_user_by_email(email) do
      nil ->
        # Run the password hash to prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        if User.verify_password(password, user.password) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{subscription_plan: "paid"})
      {:ok, %User{}}

      iex> update_user(user, %{email: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a user's password.

  ## Examples

      iex> update_user_password(user, "new_password")
      {:ok, %User{}}

      iex> update_user_password(user, "short")
      {:error, %Ecto.Changeset{}}
  """
  def update_user_password(%User{} = user, password) do
    user
    |> User.password_changeset(%{password: password})
    |> Repo.update()
  end

  def delete_user(user_id) do
    case get_user(user_id) do
      nil ->
        {:error, :not_found}

      user ->
        Repo.delete(user)
    end
  end

  @doc """
  Gets a user by verification token.
  """
  def get_user_by_verification_token(token) do
    Repo.get_by(User, email_verification_token: token)
  end

  @doc """
  Verifies a user's email with the given token.
  Returns {:ok, user} if successful, {:error, reason} otherwise.

  ## Examples

      iex> verify_user_email("valid_token")
      {:ok, %User{email_verified: true}}

      iex> verify_user_email("invalid_token")
      {:error, :invalid_token}
  """
  def verify_user_email(token) do
    case get_user_by_verification_token(token) do
      nil ->
        {:error, :invalid_token}

      user ->
        user
        |> User.verify_email_changeset()
        |> Repo.update()
        |> case do
          {:ok, user} ->
            Logger.info("Email verified for user: #{user.email}")
            {:ok, user}

          {:error, changeset} ->
            Logger.error("Failed to verify email: #{inspect(changeset.errors)}")
            {:error, :verification_failed}
        end
    end
  end

  # Alert functions

  @doc """
  Gets all alerts for a user.
  """
  def list_user_alerts(%User{id: user_id}), do: list_user_alerts(user_id)

  def list_user_alerts(user_id) do
    Alert
    |> where([a], a.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Gets a single alert by ID.
  """
  def get_alert(id), do: Repo.get(Alert, id)

  @doc """
  Creates an alert.

  ## Examples

      iex> create_alert(%{user_id: 1, rules: %{region: "mazowieckie", tender_category: "Dostawy"}})
      {:ok, %Alert{}}

      iex> create_alert(%{user_id: 1, rules: %{}})
      {:error, %Ecto.Changeset{}}
  """
  def create_alert(attrs) do
    %Alert{}
    |> Alert.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a simple alert for free plan users.
  """
  def create_simple_alert(attrs) do
    %Alert{}
    |> Alert.simple_alert_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an alert.

  ## Examples

      iex> update_alert(alert, %{rules: %{region: "malopolskie", tender_category: "Usługi"}})
      {:ok, %Alert{}}
  """
  def update_alert(%Alert{} = alert, attrs) do
    alert
    |> Alert.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an alert.

  ## Examples

      iex> delete_alert(alert)
      {:ok, %Alert{}}
  """
  def delete_alert(%Alert{} = alert) do
    Repo.delete(alert)
  end
end
