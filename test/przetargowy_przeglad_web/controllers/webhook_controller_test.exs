defmodule PrzetargowyPrzegladWeb.WebhookControllerTest do
  use PrzetargowyPrzegladWeb.ConnCase, async: true

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzeglad.Payments
  alias PrzetargowyPrzeglad.Payments.Subscription
  alias PrzetargowyPrzeglad.Repo

  defp create_user do
    {:ok, %{user: user}} =
      Accounts.register_user(%{
        email: "test#{System.unique_integer()}@example.com",
        password: "password123",
        tender_category: "Dostawy",
        region: "mazowieckie"
      })

    user
  end

  defp create_subscription(user) do
    {:ok, subscription} =
      %Subscription{}
      |> Subscription.create_changeset(%{
        user_id: user.id,
        amount: Decimal.new("19.00"),
        currency: "PLN"
      })
      |> Repo.insert()

    subscription
  end

  describe "POST /webhooks/stripe" do
    test "processes checkout.session.completed webhook", %{conn: conn} do
      user = create_user()
      subscription = create_subscription(user)

      payload = %{
        "type" => "checkout.session.completed",
        "data" => %{
          "object" => %{
            "id" => "cs_test_123",
            "subscription" => "sub_test_123",
            "customer" => "cus_test_123",
            "amount_total" => 1900,
            "metadata" => %{
              "user_id" => to_string(user.id),
              "subscription_id" => to_string(subscription.id)
            }
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/stripe", payload)

      response_body = Jason.decode!(response(conn, 200))
      assert response_body["received"] == true

      # Verify subscription was activated
      updated_subscription = Payments.get_subscription(subscription.id)
      assert updated_subscription.status == "active"
      assert updated_subscription.stripe_subscription_id == "sub_test_123"
    end

    test "processes invoice.payment_succeeded webhook for renewal", %{conn: conn} do
      user = create_user()

      {:ok, subscription} =
        %Subscription{}
        |> Subscription.create_changeset(%{
          user_id: user.id,
          amount: Decimal.new("19.00"),
          currency: "PLN"
        })
        |> Repo.insert()

      # Activate the subscription first
      {:ok, subscription} =
        subscription
        |> Subscription.activate_changeset(%{
          stripe_subscription_id: "sub_renewal_123",
          stripe_customer_id: "cus_renewal_123"
        })
        |> Repo.update()

      payload = %{
        "type" => "invoice.payment_succeeded",
        "data" => %{
          "object" => %{
            "id" => "in_test_123",
            "subscription" => "sub_renewal_123",
            "customer" => "cus_renewal_123",
            "amount_paid" => 1900,
            "payment_intent" => "pi_test_123"
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/stripe", payload)

      response_body = Jason.decode!(response(conn, 200))
      assert response_body["received"] == true

      # Verify subscription was renewed
      updated_subscription = Payments.get_subscription(subscription.id)
      assert updated_subscription.status == "active"
    end

    test "processes invoice.payment_failed webhook", %{conn: conn} do
      user = create_user()

      {:ok, subscription} =
        %Subscription{}
        |> Subscription.create_changeset(%{
          user_id: user.id,
          amount: Decimal.new("19.00"),
          currency: "PLN"
        })
        |> Repo.insert()

      {:ok, subscription} =
        subscription
        |> Subscription.activate_changeset(%{
          stripe_subscription_id: "sub_failed_123",
          stripe_customer_id: "cus_failed_123"
        })
        |> Repo.update()

      payload = %{
        "type" => "invoice.payment_failed",
        "data" => %{
          "object" => %{
            "id" => "in_failed_123",
            "subscription" => "sub_failed_123",
            "last_finalization_error" => %{
              "message" => "Your card was declined"
            }
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/stripe", payload)

      response_body = Jason.decode!(response(conn, 200))
      assert response_body["received"] == true

      # Verify subscription retry count was increased
      updated_subscription = Payments.get_subscription(subscription.id)
      assert updated_subscription.retry_count == 1
    end

    test "handles unknown event type gracefully", %{conn: conn} do
      payload = %{
        "type" => "unknown.event.type",
        "data" => %{"object" => %{}}
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/stripe", payload)

      response_body = Jason.decode!(response(conn, 200))
      assert response_body["received"] == true
    end

    test "handles malformed payload", %{conn: conn} do
      payload = %{"invalid" => "data"}

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/stripe", payload)

      # Should return 200 even for errors
      response_body = Jason.decode!(response(conn, 200))
      assert response_body["received"] == true
    end
  end
end
