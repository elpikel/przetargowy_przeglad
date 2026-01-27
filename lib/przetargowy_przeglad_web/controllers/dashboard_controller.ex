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

  def update_alerts(conn, params) do
    user = conn.assigns.current_user
    alerts = Accounts.list_user_alerts(user)
    alert = List.first(alerts)

    rules =
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
          industry: params["industry"],
          region: params["region"]
        }
      end

    case alert do
      nil ->
        Accounts.create_alert(%{user_id: user.id, rules: rules})

      existing_alert ->
        Accounts.update_alert(existing_alert, %{rules: rules})
    end

    conn
    |> put_flash(:info, "Zmiany zostały zapisane")
    |> redirect(to: ~p"/dashboard")
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
end
