defmodule PrzetargowyPrzegladWeb.SubscriptionControllerTest do
  use PrzetargowyPrzegladWeb.ConnCase, async: true

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzeglad.Payments
  alias PrzetargowyPrzeglad.Payments.PaymentTransaction
  alias PrzetargowyPrzeglad.Payments.Subscription
  alias PrzetargowyPrzeglad.Repo

  setup %{conn: conn} do
    # Create and verify a free user
    {:ok, %{user: user}} =
      Accounts.register_user(%{
        email: "test#{System.unique_integer()}@example.com",
        password: "password123",
        tender_category: "Dostawy",
        region: "mazowieckie"
      })

    {:ok, verified_user} = Accounts.verify_user_email(user.email_verification_token)

    conn =
      conn
      |> init_test_session(%{})
      |> put_session(:user_id, verified_user.id)

    %{conn: conn, user: verified_user}
  end

  defp create_subscription(user, status \\ "pending") do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    period_end = DateTime.add(now, 30, :day)

    attrs =
      if status == "active" do
        %{
          user_id: user.id,
          status: "active",
          current_period_start: now,
          current_period_end: period_end,
          tpay_subscription_id: "test_token_#{System.unique_integer()}"
        }
      else
        %{user_id: user.id}
      end

    {:ok, subscription} =
      %Subscription{}
      |> Ecto.Changeset.change(attrs)
      |> Repo.insert()

    subscription
  end

  defp create_transaction(subscription, user) do
    {:ok, transaction} =
      %PaymentTransaction{}
      |> PaymentTransaction.create_changeset(%{
        subscription_id: subscription.id,
        user_id: user.id,
        type: "initial",
        amount: Decimal.new("19.00")
      })
      |> Repo.insert()

    transaction
  end

  describe "GET /dashboard/subscription (show)" do
    test "renders subscription page for user without subscription", %{conn: conn} do
      conn = get(conn, ~p"/dashboard/subscription")

      response = html_response(conn, 200)
      assert response =~ "Subskrypcja Premium"
      assert response =~ "Brak aktywnej subskrypcji"
      assert response =~ "Wykup Premium"
    end

    test "renders subscription status for user with active subscription", %{conn: conn, user: user} do
      _subscription = create_subscription(user, "active")

      conn = get(conn, ~p"/dashboard/subscription")

      response = html_response(conn, 200)
      assert response =~ "Status subskrypcji"
      assert response =~ "Aktywna"
      assert response =~ "Anuluj subskrypcję"
    end

    test "shows cancellation notice for subscription marked for cancellation", %{conn: conn, user: user} do
      subscription = create_subscription(user, "active")

      {:ok, _} =
        subscription
        |> Ecto.Changeset.change(%{
          cancel_at_period_end: true,
          cancelled_at: DateTime.truncate(DateTime.utc_now(), :second)
        })
        |> Repo.update()

      conn = get(conn, ~p"/dashboard/subscription")

      response = html_response(conn, 200)
      assert response =~ "została anulowana"
    end

    test "shows reactivate button for cancelled subscription", %{conn: conn, user: user} do
      subscription = create_subscription(user, "active")

      {:ok, _} =
        subscription
        |> Ecto.Changeset.change(%{
          cancel_at_period_end: true,
          cancelled_at: DateTime.truncate(DateTime.utc_now(), :second)
        })
        |> Repo.update()

      conn = get(conn, ~p"/dashboard/subscription")

      response = html_response(conn, 200)
      assert response =~ "Wznów subskrypcję"
      refute response =~ "Anuluj subskrypcję"
    end

    test "shows payment history when transactions exist", %{conn: conn, user: user} do
      subscription = create_subscription(user)
      transaction = create_transaction(subscription, user)

      {:ok, _} =
        transaction
        |> PaymentTransaction.complete_changeset(%{})
        |> Repo.update()

      conn = get(conn, ~p"/dashboard/subscription")

      response = html_response(conn, 200)
      assert response =~ "Historia płatności"
      assert response =~ "Pierwsza płatność"
    end
  end

  describe "GET /dashboard/subscription/new" do
    test "renders upgrade page for free user", %{conn: conn} do
      conn = get(conn, ~p"/dashboard/subscription/new")

      response = html_response(conn, 200)
      assert response =~ "Plan Premium"
      assert response =~ "19"
      assert response =~ "Nieograniczona liczba alertów"
      assert response =~ "Wszystkie regiony"
      assert response =~ "Własne słowa kluczowe"
    end

    test "redirects to subscription page if user already has active subscription", %{conn: conn, user: user} do
      _subscription = create_subscription(user, "active")

      conn = get(conn, ~p"/dashboard/subscription/new")

      assert redirected_to(conn) == ~p"/dashboard/subscription"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "aktywną subskrypcję"
    end
  end

  describe "DELETE /dashboard/subscription (cancel)" do
    test "cancels active subscription at period end", %{conn: conn, user: user} do
      _subscription = create_subscription(user, "active")

      conn = delete(conn, ~p"/dashboard/subscription")

      assert redirected_to(conn) == ~p"/dashboard/subscription"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "anulowana"

      # Check subscription was marked for cancellation
      updated_subscription = Payments.get_user_subscription(user.id)
      assert updated_subscription.cancel_at_period_end == true
      assert updated_subscription.cancelled_at
    end

    test "returns error when user has no subscription", %{conn: conn} do
      conn = delete(conn, ~p"/dashboard/subscription")

      assert redirected_to(conn) == ~p"/dashboard/subscription"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Nie masz aktywnej"
    end
  end

  describe "GET /dashboard/subscription/success" do
    test "redirects to subscription page with success message", %{conn: conn} do
      conn = get(conn, ~p"/dashboard/subscription/success")

      assert redirected_to(conn) == ~p"/dashboard/subscription"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "zainicjowana"
    end
  end

  describe "GET /dashboard/subscription/error" do
    test "redirects to new subscription page with error message", %{conn: conn} do
      conn = get(conn, ~p"/dashboard/subscription/error")

      assert redirected_to(conn) == ~p"/dashboard/subscription/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "błąd"
    end
  end

  describe "POST /dashboard/subscription/reactivate" do
    test "reactivates a cancelled subscription", %{conn: conn, user: user} do
      subscription = create_subscription(user, "active")

      # First cancel the subscription
      {:ok, _} =
        subscription
        |> Ecto.Changeset.change(%{
          cancel_at_period_end: true,
          cancelled_at: DateTime.truncate(DateTime.utc_now(), :second)
        })
        |> Repo.update()

      # Now reactivate
      conn = post(conn, ~p"/dashboard/subscription/reactivate")

      assert redirected_to(conn) == ~p"/dashboard/subscription"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "wznowiona"

      # Check subscription was reactivated
      updated_subscription = Payments.get_user_subscription(user.id)
      assert updated_subscription.cancel_at_period_end == false
      assert updated_subscription.cancelled_at == nil
    end

    test "returns error when user has no subscription", %{conn: conn} do
      conn = post(conn, ~p"/dashboard/subscription/reactivate")

      assert redirected_to(conn) == ~p"/dashboard/subscription"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Nie masz aktywnej"
    end

    test "returns error when subscription is not marked for cancellation", %{conn: conn, user: user} do
      _subscription = create_subscription(user, "active")

      conn = post(conn, ~p"/dashboard/subscription/reactivate")

      assert redirected_to(conn) == ~p"/dashboard/subscription"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Nie można wznowić"
    end
  end

  describe "authentication required" do
    test "redirects to login when not authenticated", %{conn: conn} do
      # Clear the session
      conn =
        conn
        |> delete_session(:user_id)
        |> get(~p"/dashboard/subscription")

      assert redirected_to(conn) == ~p"/login"
    end
  end
end
