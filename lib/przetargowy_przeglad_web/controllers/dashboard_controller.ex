defmodule PrzetargowyPrzegladWeb.DashboardController do
  use PrzetargowyPrzegladWeb, :controller

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzeglad.Accounts.User

  def show_dashboard(conn, _params) do
    user = conn.assigns.current_user
    alerts = Accounts.list_user_alerts(user)
    alert = List.first(alerts)
    password_changeset = User.password_change_changeset()

    render(conn, :show_dashboard,
      current_user: user,
      alerts: alerts,
      alert: alert,
      password_changeset: password_changeset
    )
  end

  def update_alert(conn, params) do
    user = conn.assigns.current_user
    alert_id = params["alert_id"]

    alert =
      if alert_id do
        Accounts.get_alert(alert_id)
      else
        # For backwards compatibility, get first alert if no ID provided
        user |> Accounts.list_user_alerts() |> List.first()
      end

    # Verify the alert belongs to this user
    if alert && alert.user_id == user.id do
      rules = build_rules(user, params)
      Accounts.update_alert(alert, %{rules: rules})

      conn
      |> put_flash(:info, "Zmiany zostały zapisane")
      |> redirect(to: ~p"/dashboard")
    else
      conn
      |> put_flash(:error, "Nie znaleziono alertu")
      |> redirect(to: ~p"/dashboard")
    end
  end

  def create_alert(conn, params) do
    user = conn.assigns.current_user
    redirect_path = params["redirect_to"] || ~p"/dashboard"

    # Only premium users can have multiple alerts
    if user.subscription_plan == "paid" do
      rules = build_rules(user, params)

      case Accounts.create_alert(%{user_id: user.id, rules: rules}) do
        {:ok, _alert} ->
          conn
          |> put_flash(:info, "✓ Alert został dodany pomyślnie")
          |> redirect(to: redirect_path)

        {:error, _changeset} ->
          conn
          |> put_flash(:error, "Nie udało się dodać alertu")
          |> redirect(to: redirect_path)
      end
    else
      # Free users can only have one alert
      conn
      |> put_flash(:error, "Funkcja dostępna tylko w planie Premium")
      |> redirect(to: redirect_path)
    end
  end

  def delete_alert(conn, %{"id" => alert_id}) do
    user = conn.assigns.current_user
    alert = Accounts.get_alert(alert_id)

    cond do
      # Alert doesn't exist
      is_nil(alert) ->
        conn
        |> put_flash(:error, "Nie znaleziono alertu")
        |> redirect(to: ~p"/dashboard")

      # Alert doesn't belong to user
      alert.user_id != user.id ->
        conn
        |> put_flash(:error, "Nie masz uprawnień do usunięcia tego alertu")
        |> redirect(to: ~p"/dashboard")

      # Free users cannot delete their only alert
      user.subscription_plan == "free" ->
        conn
        |> put_flash(:error, "Nie możesz usunąć jedynego alertu w planie darmowym")
        |> redirect(to: ~p"/dashboard")

      # Premium users must have at least one alert
      user.subscription_plan == "paid" && length(Accounts.list_user_alerts(user)) <= 1 ->
        conn
        |> put_flash(:error, "Musisz mieć co najmniej jeden alert")
        |> redirect(to: ~p"/dashboard")

      # Delete the alert
      true ->
        case Accounts.delete_alert(alert) do
          {:ok, _} ->
            conn
            |> put_flash(:info, "Alert został usunięty")
            |> redirect(to: ~p"/dashboard")

          {:error, _} ->
            conn
            |> put_flash(:error, "Nie udało się usunąć alertu")
            |> redirect(to: ~p"/dashboard")
        end
    end
  end

  def update_password(conn, %{"password_form" => %{"password" => password} = form_params}) do
    user = conn.assigns.current_user
    changeset = User.password_change_changeset(form_params)

    if changeset.valid? do
      case Accounts.update_user_password(user, password) do
        {:ok, _user} ->
          conn
          |> put_flash(:info, "Hasło zostało zmienione")
          |> redirect(to: ~p"/dashboard")

        {:error, _changeset} ->
          alerts = Accounts.list_user_alerts(user)
          alert = List.first(alerts)

          conn
          |> put_status(:unprocessable_entity)
          |> render(:show_dashboard,
            current_user: user,
            alerts: alerts,
            alert: alert,
            password_changeset: %{changeset | action: :validate}
          )
      end
    else
      alerts = Accounts.list_user_alerts(user)
      alert = List.first(alerts)

      conn
      |> put_status(:unprocessable_entity)
      |> render(:show_dashboard,
        current_user: user,
        alerts: alerts,
        alert: alert,
        password_changeset: %{changeset | action: :validate}
      )
    end
  end

  # Helper function to build rules based on subscription plan
  defp build_rules(user, params) do
    if user.subscription_plan == "paid" do
      keywords =
        case params["keywords"] do
          nil -> []
          "" -> []
          kw -> kw |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.filter(&(&1 != ""))
        end

      %{
        industries: params["industries"] || [],
        regions: params["regions"] || [],
        keywords: keywords
      }
    else
      %{
        tender_category: params["tender_category"],
        region: params["region"]
      }
    end
  end
end
