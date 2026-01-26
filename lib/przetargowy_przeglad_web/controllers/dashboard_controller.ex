defmodule PrzetargowyPrzegladWeb.DashboardController do
  use PrzetargowyPrzegladWeb, :controller

  alias PrzetargowyPrzeglad.Accounts

  def show_dashboard(conn, _params) do
    user = conn.assigns.current_user
    alerts = Accounts.list_user_alerts(user)
    alert = List.first(alerts)

    render(conn, :show_dashboard,
      current_user: user,
      alerts: alerts,
      alert: alert
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
            kw -> String.split(kw, ",") |> Enum.map(&String.trim/1) |> Enum.filter(&(&1 != ""))
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
end
