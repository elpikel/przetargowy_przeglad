defmodule PrzetargowyPrzeglad.Factory do
  @moduledoc """
  Factory for generating test data using ExMachina.
  """
  use ExMachina.Ecto, repo: PrzetargowyPrzeglad.Repo

  alias PrzetargowyPrzeglad.Accounts.Alert
  alias PrzetargowyPrzeglad.Accounts.User
  alias PrzetargowyPrzeglad.Tenders.TenderNotice

  # User factories

  def user_factory do
    %User{
      email: sequence(:email, &"user#{&1}@example.com"),
      password: Bcrypt.hash_pwd_salt("password123"),
      subscription_plan: "free",
      email_verified: false,
      email_verification_token: generate_token(),
      email_verification_sent_at: DateTime.truncate(DateTime.utc_now(), :second)
    }
  end

  def verified_user_factory do
    struct!(
      user_factory(),
      %{
        email_verified: true,
        email_verification_token: nil
      }
    )
  end

  def premium_user_factory do
    struct!(
      user_factory(),
      %{
        subscription_plan: "paid"
      }
    )
  end

  def verified_premium_user_factory do
    struct!(
      user_factory(),
      %{
        subscription_plan: "paid",
        email_verified: true,
        email_verification_token: nil
      }
    )
  end

  # Alert factories

  def simple_alert_factory do
    %Alert{
      user: build(:verified_user),
      rules: %{
        region: "mazowieckie",
        tender_category: "Dostawy"
      }
    }
  end

  def premium_alert_factory do
    %Alert{
      user: build(:verified_premium_user),
      rules: %{
        industries: ["it"],
        regions: ["mazowieckie"],
        keywords: ["software"]
      }
    }
  end

  # TenderNotice factories

  def tender_notice_factory do
    %TenderNotice{
      object_id: sequence(:object_id, &"notice-#{&1}"),
      client_type: "1.1.5",
      order_type: "Delivery",
      tender_type: "1.1.1",
      notice_type: "ContractNotice",
      notice_number: sequence(:notice_number, &"2024/BZP #{String.pad_leading("#{&1}", 8, "0")}/01"),
      bzp_number: sequence(:bzp_number, &"2024/BZP #{String.pad_leading("#{&1}", 7, "0")}"),
      is_tender_amount_below_eu: true,
      publication_date: DateTime.utc_now(),
      order_object: "Test tender notice",
      cpv_codes: ["09100000-0"],
      submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
      procedure_result: nil,
      organization_name: "Test Organization",
      organization_city: "Warszawa",
      organization_province: "PL14",
      organization_country: "PL",
      organization_national_id: "1234567890",
      organization_id: sequence(:organization_id, &"org-#{&1}"),
      tender_id: sequence(:tender_id, &"ocds-148610-test-#{&1}"),
      html_body: "<html><body>Test tender</body></html>",
      contractors: [],
      estimated_values: [],
      estimated_value: Decimal.new("10000"),
      total_contract_value: nil,
      total_contractors_contracts_count: 0,
      cancelled_count: 0,
      contractors_contract_details: []
    }
  end

  def mazowieckie_tender_factory do
    struct!(
      tender_notice_factory(),
      %{
        organization_province: "PL14",
        organization_city: "Warszawa",
        order_object: "Przetarg mazowiecki"
      }
    )
  end

  def malopolskie_tender_factory do
    struct!(
      tender_notice_factory(),
      %{
        organization_province: "PL12",
        organization_city: "Kraków",
        order_object: "Przetarg małopolski"
      }
    )
  end

  def wielkopolskie_tender_factory do
    struct!(
      tender_notice_factory(),
      %{
        organization_province: "PL16",
        organization_city: "Poznań",
        order_object: "Przetarg wielkopolski"
      }
    )
  end

  def slaskie_tender_factory do
    struct!(
      tender_notice_factory(),
      %{
        organization_province: "PL11",
        organization_city: "Katowice",
        order_object: "Przetarg śląski"
      }
    )
  end

  def delivery_tender_factory do
    struct!(
      tender_notice_factory(),
      %{
        order_type: "Delivery",
        order_object: "Dostawa towarów"
      }
    )
  end

  def services_tender_factory do
    struct!(
      tender_notice_factory(),
      %{
        order_type: "Services",
        order_object: "Świadczenie usług"
      }
    )
  end

  def works_tender_factory do
    struct!(
      tender_notice_factory(),
      %{
        order_type: "Works",
        order_object: "Roboty budowlane"
      }
    )
  end

  # Helper functions

  defp generate_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
