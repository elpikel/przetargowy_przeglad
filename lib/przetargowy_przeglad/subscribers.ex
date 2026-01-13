defmodule PrzetargowyPrzeglad.Subscribers do
  import Ecto.Query
  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Subscribers.Subscriber

  @confirmed Subscriber.confirmed()

  def subscribe(attrs) do
    %Subscriber{}
    |> Subscriber.signup_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, subscriber} ->
        send_confirmation_email(subscriber)
        {:ok, subscriber}

      error ->
        error
    end
  end

  def confirm_subscription(token) do
    case get_by_token(token) do
      nil ->
        {:error, :invalid_token}

      %Subscriber{status: @confirmed} ->
        {:error, :already_confirmed}

      subscriber ->
        subscriber
        |> Subscriber.confirm_changeset()
        |> Repo.update()
    end
  end

  def unsubscribe(email) do
    case get_by_email(email) do
      nil ->
        {:error, :not_found}

      subscriber ->
        subscriber
        |> Subscriber.unsubscribe_changeset()
        |> Repo.update()
    end
  end

  def get_by_email(email) do
    Repo.get_by(Subscriber, email: String.downcase(email))
  end

  def get_by_token(token) do
    Repo.get_by(Subscriber, confirmation_token: token)
  end

  def list_confirmed do
    Subscriber
    |> where([s], s.status == @confirmed)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def count_by_status do
    Subscriber
    |> group_by([s], s.status)
    |> select([s], {s.status, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  defp send_confirmation_email(subscriber) do
    subscriber
    |> PrzetargowyPrzeglad.Email.ConfirmationEmail.build()
    |> PrzetargowyPrzeglad.Mailer.deliver()
  end
end
