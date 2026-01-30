defmodule PrzetargowyPrzeglad.Workers.SendAlerts do
  @moduledoc """
  Oban worker that sends alert emails to users with matching tender notices.
  """
  use Oban.Worker,
    queue: :alerts,
    max_attempts: 3,
    unique: [period: 3600]

  import Ecto.Query

  alias PrzetargowyPrzeglad.Accounts.Alert
  alias PrzetargowyPrzeglad.Accounts.AlertEmail
  alias PrzetargowyPrzeglad.Accounts.User
  alias PrzetargowyPrzeglad.Mailer
  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Tenders.TenderNotice

  require Logger

  @impl Oban.Worker
  def perform(_) do
    alerts =
      Alert
      |> from(as: :alert)
      |> join(:inner, [alert: a], u in User, on: a.user_id == u.id, as: :user)
      |> where([user: u], u.email_verified == true)
      |> select([alert: a, user: u], %{email: u.email, rules: a.rules})
      |> Repo.all()

    Enum.each(alerts, fn alert ->
      send_alert_email(alert)
    end)

    :ok
  end

  defp send_alert_email(%{email: email, rules: %{"region" => region, "tender_category" => tender_category} = rules}) do
    Logger.info("Processing alert for #{email} with rules: #{inspect(rules)}")

    notices = fetch_matching_notices(region, tender_category)

    if Enum.empty?(notices) do
      Logger.info("No matching notices for #{email}, skipping email")
    else
      Logger.info("Found #{length(notices)} notices for #{email}, sending email")

      email
      |> AlertEmail.compose(notices, tender_category)
      |> Mailer.deliver()
      |> case do
        {:ok, _} ->
          Logger.info("Alert email sent successfully to #{email}")

        {:error, reason} ->
          Logger.error("Failed to send alert email to #{email}: #{inspect(reason)}")
      end
    end
  end

  defp send_alert_email(%{email: email, rules: rules}) do
    Logger.warning("Skipping alert for #{email} - unsupported rules format: #{inspect(rules)}")
  end

  defp fetch_matching_notices(region, tender_category) do
    province_code = region_to_province_code(region)
    order_type = to_order_type(tender_category)

    TenderNotice
    |> from(as: :tender_notice)
    |> where(
      [tender_notice: tn],
      tn.organization_province == ^province_code and
        tn.order_type == ^order_type and
        tn.notice_type == "ContractNotice" and
        tn.submitting_offers_date >= ^DateTime.utc_now()
    )
    |> select([tender_notice: tn], tn)
    |> order_by([tender_notice: tn], asc: tn.submitting_offers_date)
    |> limit(10)
    |> Repo.all()
  end

  defp to_order_type(tender_category) do
    case tender_category do
      "Dostawy" -> "Delivery"
      "Usługi" -> "Services"
      "Roboty budowlane" -> "Works"
      _ -> nil
    end
  end

  defp region_to_province_code(region) do
    case region do
      "dolnoslaskie" -> "PL02"
      "kujawsko-pomorskie" -> "PL04"
      "lubelskie" -> "PL06"
      "lubuskie" -> "PL08"
      "lodzkie" -> "PL10"
      "malopolskie" -> "PL12"
      "mazowieckie" -> "PL14"
      "opolskie" -> "PL16"
      "podkarpackie" -> "PL18"
      "podlaskie" -> "PL20"
      "pomorskie" -> "PL22"
      "slaskie" -> "PL24"
      "swietokrzyskie" -> "PL26"
      "warminsko-mazurskie" -> "PL28"
      "wielkopolskie" -> "PL30"
      "zachodniopomorskie" -> "PL32"
      _ -> nil
    end
  end
end
