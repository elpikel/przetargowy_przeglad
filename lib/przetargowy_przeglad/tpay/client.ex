defmodule PrzetargowyPrzeglad.Tpay.Client do
  @moduledoc """
  HTTP client for Tpay payment gateway API.
  Uses OAuth2 for authentication and Req for HTTP requests.

  ## Configuration

  Required environment variables:
  - TPAY_CLIENT_ID - OAuth2 client ID
  - TPAY_CLIENT_SECRET - OAuth2 client secret
  - TPAY_MERCHANT_ID - Merchant account ID

  Optional:
  - TPAY_API_URL - API base URL (defaults to sandbox)

  ## Usage

      # Create a transaction for card registration
      Tpay.Client.create_transaction(%{
        amount: 19.00,
        description: "Premium subscription",
        payer: %{email: "user@example.com", name: "John Doe"},
        callbacks: %{
          payerUrls: %{
            success: "https://example.com/success",
            error: "https://example.com/error"
          },
          notification: %{url: "https://example.com/webhooks/tpay"}
        },
        pay: %{groupId: 103}  # Card payments group
      })
  """

  require Logger

  @sandbox_api_url "https://openapi.sandbox.tpay.com"
  # Production URL: https://api.tpay.com (configured via TPAY_API_URL env var)
  @timeout 30_000
  @retry_attempts 3
  @retry_delay 1_000

  # Token cache using ETS (simple in-memory cache)
  @token_table :tpay_token_cache

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Creates a new transaction for initial payment with card registration.
  Returns a redirect URL where the user completes the payment.
  """
  def create_transaction(params) do
    body =
      Map.merge(
        %{
          "amount" => params.amount,
          "description" => params.description,
          "hiddenDescription" => params[:hidden_description] || "subscription_payment",
          "payer" => %{
            "email" => params.payer.email,
            "name" => params.payer[:name] || params.payer.email
          },
          "callbacks" => %{
            "payerUrls" => %{
              "success" => params.callbacks.success_url,
              "error" => params.callbacks.error_url
            },
            "notification" => %{
              "url" => params.callbacks.notification_url
            }
          },
          "pay" => %{
            "groupId" => 103,
            "cardPaymentData" => %{
              "save" => true
            }
          }
        },
        params[:extra] || %{}
      )

    case post("/transactions", body) do
      {:ok, %{"title" => transaction_id, "transactionPaymentUrl" => url} = response} ->
        Logger.info("Tpay transaction created: id=#{transaction_id}, url=#{url}")
        {:ok, %{transaction_id: transaction_id, payment_url: url, response: response}}

      {:ok, response} ->
        Logger.error("Tpay: Unexpected transaction response: #{inspect(response, pretty: true)}")
        {:error, :unexpected_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Charges a recurring payment using a saved card token.
  Used for subscription renewals.
  """
  def charge_recurring(card_token, params) do
    body = %{
      "amount" => params.amount,
      "description" => params.description,
      "hiddenDescription" => params[:hidden_description] || "subscription_renewal",
      "payer" => %{
        "email" => params.payer.email,
        "name" => params.payer[:name] || params.payer.email
      },
      "pay" => %{
        "groupId" => 103,
        "cardPaymentData" => %{
          "token" => card_token
        }
      },
      "callbacks" => %{
        "notification" => %{
          "url" => params.callbacks.notification_url
        }
      }
    }

    case post("/transactions", body) do
      {:ok, %{"transactionId" => transaction_id, "status" => status} = response} ->
        {:ok, %{transaction_id: transaction_id, status: status, response: response}}

      {:ok, response} ->
        Logger.error("Tpay: Unexpected recurring charge response: #{inspect(response)}")
        {:error, :unexpected_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the status of a transaction.
  """
  def get_transaction(transaction_id) do
    case get("/transactions/#{transaction_id}") do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deauthorizes (removes) a saved card token.
  Used when cancelling a subscription.
  """
  def deauthorize_card(card_token) do
    case delete("/tokens/#{card_token}") do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Requests a refund for a transaction.
  """
  def refund_transaction(transaction_id, amount) do
    body = %{
      "amount" => amount
    }

    case post("/transactions/#{transaction_id}/refunds", body) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # OAuth2 Token Management
  # ============================================================================

  @doc """
  Gets a valid access token, refreshing if necessary.
  """
  def get_access_token do
    init_token_table()

    case get_cached_token() do
      {:ok, token} ->
        {:ok, token}

      :expired ->
        refresh_token()
    end
  end

  defp init_token_table do
    if :ets.whereis(@token_table) == :undefined do
      :ets.new(@token_table, [:named_table, :public, :set])
    end
  end

  defp get_cached_token do
    case :ets.lookup(@token_table, :access_token) do
      [{:access_token, token, expires_at}] ->
        if DateTime.before?(DateTime.utc_now(), expires_at) do
          {:ok, token}
        else
          :expired
        end

      [] ->
        :expired
    end
  end

  defp refresh_token do
    client_id = config(:client_id)
    client_secret = config(:client_secret)

    body = %{
      "client_id" => client_id,
      "client_secret" => client_secret,
      "grant_type" => "client_credentials",
      "scope" => "read write"
    }

    case Req.post("#{api_url()}/oauth/auth",
           json: body,
           headers: [{"Content-Type", "application/json"}],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: %{"access_token" => token, "expires_in" => expires_in}}} ->
        expires_at = DateTime.add(DateTime.utc_now(), expires_in - 60, :second)
        :ets.insert(@token_table, {:access_token, token, expires_at})
        {:ok, token}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Tpay OAuth error: status=#{status}, body=#{inspect(body)}")
        {:error, {:oauth_error, status}}

      {:error, reason} ->
        Logger.error("Tpay OAuth request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ============================================================================
  # HTTP Request Helpers
  # ============================================================================

  defp get(path) do
    make_request(:get, path, nil)
  end

  defp post(path, body) do
    make_request(:post, path, body)
  end

  defp delete(path) do
    make_request(:delete, path, nil)
  end

  defp make_request(method, path, body, attempt \\ 1) do
    with {:ok, token} <- get_access_token() do
      url = "#{api_url()}#{path}"

      headers = [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ]

      result =
        case method do
          :get ->
            Req.get(url, headers: headers, receive_timeout: @timeout)

          :post ->
            Req.post(url, json: body, headers: headers, receive_timeout: @timeout)

          :delete ->
            Req.delete(url, headers: headers, receive_timeout: @timeout)
        end

      case result do
        {:ok, %{status: status, body: response_body}} when status in 200..299 ->
          {:ok, response_body}

        {:ok, %{status: 401}} ->
          # Token expired, clear cache and retry
          :ets.delete(@token_table, :access_token)

          if attempt < @retry_attempts do
            make_request(method, path, body, attempt + 1)
          else
            {:error, :unauthorized}
          end

        {:ok, %{status: status, body: error_body}} ->
          Logger.warning("Tpay API error: status=#{status}, body=#{inspect(error_body)}")
          {:error, {:http_error, status, error_body}}

        {:error, reason} ->
          Logger.warning("Tpay request failed: #{inspect(reason)}")
          maybe_retry(method, path, body, attempt, reason)
      end
    end
  end

  defp maybe_retry(method, path, body, attempt, _error) when attempt < @retry_attempts do
    delay = @retry_delay * attempt
    Logger.info("Tpay: Retrying request in #{delay}ms (attempt #{attempt + 1}/#{@retry_attempts})")
    Process.sleep(delay)
    make_request(method, path, body, attempt + 1)
  end

  defp maybe_retry(_method, _path, _body, _attempt, error), do: {:error, error}

  # ============================================================================
  # Configuration
  # ============================================================================

  defp api_url do
    config(:api_url) || @sandbox_api_url
  end

  defp config(key) do
    :przetargowy_przeglad
    |> Application.get_env(:tpay, [])
    |> Keyword.get(key)
  end
end
