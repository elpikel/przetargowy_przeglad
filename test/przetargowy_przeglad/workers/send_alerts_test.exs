defmodule PrzetargowyPrzeglad.Workers.SendAlertsTest do
  use PrzetargowyPrzeglad.DataCase, async: true
  use Oban.Testing, repo: PrzetargowyPrzeglad.Repo

  import Swoosh.TestAssertions

  alias PrzetargowyPrzeglad.Accounts.Alert
  alias PrzetargowyPrzeglad.Accounts.User
  alias PrzetargowyPrzeglad.Tenders.TenderNotice
  alias PrzetargowyPrzeglad.Workers.SendAlerts

  @moduletag capture_log: true

  describe "perform/1" do
    test "sends email to verified user with matching tender notices" do
      # Create a verified user
      user = create_verified_user("test@example.com")

      # Create an alert for the user
      create_alert(user, %{
        "region" => "mazowieckie",
        "tender_category" => "Dostawy"
      })

      # Create matching tender notices (future submission date)
      create_tender_notice(%{
        object_id: "notice-1",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
        order_object: "Dostawa sprzętu komputerowego",
        organization_name: "Urząd Miasta Warszawa",
        organization_city: "Warszawa",
        bzp_number: "2024/BZP 00001234"
      })

      # Perform the worker
      assert :ok = perform_job(SendAlerts, %{})

      # Assert email was sent
      assert_email_sent(fn email ->
        email.to == [{"test@example.com", "test@example.com"}] and
          email.subject =~ "Dostawy"
      end)
    end

    test "does not send email to unverified user" do
      # Create an unverified user
      user = create_unverified_user("unverified@example.com")

      # Create an alert for the user
      create_alert(user, %{
        "region" => "mazowieckie",
        "tender_category" => "Dostawy"
      })

      # Create matching tender notices
      create_tender_notice(%{
        object_id: "notice-2",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
        order_object: "Dostawa materiałów biurowych",
        organization_name: "Urząd Gminy",
        organization_city: "Warszawa",
        bzp_number: "2024/BZP 00001235"
      })

      # Perform the worker
      assert :ok = perform_job(SendAlerts, %{})

      # Assert no email was sent
      refute_email_sent()
    end

    test "does not send email when no matching notices" do
      # Create a verified user
      user = create_verified_user("nonotices@example.com")

      # Create an alert for the user with different criteria
      create_alert(user, %{
        "region" => "wielkopolskie",
        "tender_category" => "Usługi"
      })

      # Create tender notice that doesn't match (different region)
      create_tender_notice(%{
        object_id: "notice-3",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
        order_object: "Dostawa paliwa",
        organization_name: "Urząd Miasta",
        organization_city: "Warszawa",
        bzp_number: "2024/BZP 00001236"
      })

      # Perform the worker
      assert :ok = perform_job(SendAlerts, %{})

      # Assert no email was sent
      refute_email_sent()
    end

    test "does not send email for expired tender notices" do
      # Create a verified user
      user = create_verified_user("expired@example.com")

      # Create an alert for the user
      create_alert(user, %{
        "region" => "mazowieckie",
        "tender_category" => "Dostawy"
      })

      # Create tender notice with past submission date
      create_tender_notice(%{
        object_id: "notice-4",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), -1, :day),
        order_object: "Dostawa żywności",
        organization_name: "Szkoła Podstawowa",
        organization_city: "Warszawa",
        bzp_number: "2024/BZP 00001237"
      })

      # Perform the worker
      assert :ok = perform_job(SendAlerts, %{})

      # Assert no email was sent
      refute_email_sent()
    end

    test "sends email only for ContractNotice type" do
      # Create a verified user
      user = create_verified_user("noticetype@example.com")

      # Create an alert for the user
      create_alert(user, %{
        "region" => "mazowieckie",
        "tender_category" => "Dostawy"
      })

      # Create tender notice with wrong notice type
      create_tender_notice(%{
        object_id: "notice-5",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "TenderResultNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
        order_object: "Dostawa sprzętu",
        organization_name: "Urząd Miasta",
        organization_city: "Warszawa",
        bzp_number: "2024/BZP 00001238"
      })

      # Perform the worker
      assert :ok = perform_job(SendAlerts, %{})

      # Assert no email was sent
      refute_email_sent()
    end

    test "handles multiple users with different alerts" do
      # Create two verified users
      user1 = create_verified_user("user1@example.com")
      user2 = create_verified_user("user2@example.com")

      # Create alerts with different criteria
      create_alert(user1, %{
        "region" => "mazowieckie",
        "tender_category" => "Dostawy"
      })

      create_alert(user2, %{
        "region" => "malopolskie",
        "tender_category" => "Usługi"
      })

      # Create tender notices matching user1's alert
      create_tender_notice(%{
        object_id: "notice-6",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
        order_object: "Dostawa komputerów",
        organization_name: "Urząd Mazowiecki",
        organization_city: "Warszawa",
        bzp_number: "2024/BZP 00001239"
      })

      # Create tender notices matching user2's alert
      create_tender_notice(%{
        object_id: "notice-7",
        organization_province: "PL12",
        order_type: "Services",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
        order_object: "Usługi sprzątania",
        organization_name: "Urząd Małopolski",
        organization_city: "Kraków",
        bzp_number: "2024/BZP 00001240"
      })

      # Perform the worker
      assert :ok = perform_job(SendAlerts, %{})

      # Assert emails were sent to both users
      assert_email_sent(fn email ->
        email.to == [{"user1@example.com", "user1@example.com"}]
      end)

      assert_email_sent(fn email ->
        email.to == [{"user2@example.com", "user2@example.com"}]
      end)
    end

    test "maps all regions to correct province codes" do
      regions_to_codes = [
        {"dolnoslaskie", "PL02"},
        {"kujawsko-pomorskie", "PL04"},
        {"lubelskie", "PL06"},
        {"lubuskie", "PL08"},
        {"lodzkie", "PL10"},
        {"malopolskie", "PL12"},
        {"mazowieckie", "PL14"},
        {"opolskie", "PL16"},
        {"podkarpackie", "PL18"},
        {"podlaskie", "PL20"},
        {"pomorskie", "PL22"},
        {"slaskie", "PL24"},
        {"swietokrzyskie", "PL26"},
        {"warminsko-mazurskie", "PL28"},
        {"wielkopolskie", "PL30"},
        {"zachodniopomorskie", "PL32"}
      ]

      for {region, province_code} <- regions_to_codes do
        # Create user and alert
        user = create_verified_user("test-#{region}@example.com")

        create_alert(user, %{
          "region" => region,
          "tender_category" => "Dostawy"
        })

        # Create matching notice
        create_tender_notice(%{
          object_id: "notice-#{region}",
          organization_province: province_code,
          order_type: "Delivery",
          notice_type: "ContractNotice",
          submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
          order_object: "Dostawa dla #{region}",
          organization_name: "Urząd #{region}",
          organization_city: "Miasto",
          bzp_number: "2024/BZP #{region}"
        })
      end

      # Perform the worker
      assert :ok = perform_job(SendAlerts, %{})

      # All 16 users should receive emails
      for {region, _} <- regions_to_codes do
        assert_email_sent(fn email ->
          email.to == [{"test-#{region}@example.com", "test-#{region}@example.com"}]
        end)
      end
    end

    test "maps all tender categories to correct order types" do
      categories_to_types = [
        {"Dostawy", "Delivery"},
        {"Usługi", "Services"},
        {"Roboty budowlane", "Works"}
      ]

      for {category, order_type} <- categories_to_types do
        user = create_verified_user("test-#{order_type}@example.com")

        create_alert(user, %{
          "region" => "mazowieckie",
          "tender_category" => category
        })

        create_tender_notice(%{
          object_id: "notice-#{order_type}",
          organization_province: "PL14",
          order_type: order_type,
          notice_type: "ContractNotice",
          submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
          order_object: "Zamówienie #{category}",
          organization_name: "Urząd Miasta",
          organization_city: "Warszawa",
          bzp_number: "2024/BZP #{order_type}"
        })
      end

      # Perform the worker
      assert :ok = perform_job(SendAlerts, %{})

      # All 3 users should receive emails
      for {_, order_type} <- categories_to_types do
        assert_email_sent(fn email ->
          email.to == [{"test-#{order_type}@example.com", "test-#{order_type}@example.com"}]
        end)
      end
    end
  end

  # Helper functions

  defp create_verified_user(email) do
    Repo.insert!(%User{
      email: email,
      password: Bcrypt.hash_pwd_salt("password123"),
      email_verified: true,
      subscription_plan: "free"
    })
  end

  defp create_unverified_user(email) do
    Repo.insert!(%User{
      email: email,
      password: Bcrypt.hash_pwd_salt("password123"),
      email_verified: false,
      email_verification_token: "some-token",
      subscription_plan: "free"
    })
  end

  defp create_alert(user, rules) do
    Repo.insert!(%Alert{
      user_id: user.id,
      rules: rules
    })
  end

  defp create_tender_notice(attrs) do
    default_attrs = %{
      notice_number: "2024/BZP 00000001/01",
      client_type: "1.1.5",
      tender_type: "1.1.1",
      is_tender_amount_below_eu: true,
      publication_date: DateTime.utc_now(),
      cpv_codes: ["09100000-0"],
      procedure_result: nil,
      organization_country: "PL",
      organization_national_id: "1234567890",
      organization_id: "1234",
      tender_id: "ocds-148610-test",
      html_body: "<html>...</html>",
      contractors: [],
      estimated_values: [],
      estimated_value: Decimal.new("10000"),
      total_contract_value: nil,
      total_contractors_contracts_count: 0,
      cancelled_count: 0,
      contractors_contract_details: []
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    %TenderNotice{}
    |> TenderNotice.changeset(merged_attrs)
    |> Repo.insert!()
  end
end
