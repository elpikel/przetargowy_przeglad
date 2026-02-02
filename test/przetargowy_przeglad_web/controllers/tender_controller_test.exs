defmodule PrzetargowyPrzegladWeb.TenderControllerTest do
  use PrzetargowyPrzegladWeb.ConnCase, async: false

  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Tenders.TenderNotice

  setup do
    # Clean up database before each test to prevent data leakage
    Repo.delete_all(TenderNotice)
    :ok
  end

  describe "GET /tenders" do
    test "renders search page", %{conn: conn} do
      conn = get(conn, ~p"/tenders")
      assert html_response(conn, 200) =~ "Wyszukaj przetargi"
      assert html_response(conn, 200) =~ "Szukaj"
    end

    test "shows empty state when no results", %{conn: conn} do
      conn = get(conn, ~p"/tenders")
      assert html_response(conn, 200) =~ "Brak wyników"
    end

    test "displays matching tender notices", %{conn: conn} do
      create_tender_notice(%{
        order_object: "Dostawa sprzętu komputerowego",
        organization_name: "Urząd Miasta Warszawa",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      conn = get(conn, ~p"/tenders")
      response = html_response(conn, 200)

      assert response =~ "Dostawa sprzętu komputerowego"
      assert response =~ "Urząd Miasta Warszawa"
      assert response =~ "Warszawa"
    end

    test "filters by text query", %{conn: conn} do
      create_tender_notice(%{
        object_id: "notice-1",
        order_object: "Dostawa komputerów",
        organization_name: "Urząd Miasta",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_tender_notice(%{
        object_id: "notice-2",
        order_object: "Usługi sprzątania",
        organization_name: "Szkoła Podstawowa",
        organization_city: "Kraków",
        organization_province: "PL12",
        order_type: "Services",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      conn = get(conn, ~p"/tenders?q=komputerów")
      response = html_response(conn, 200)

      assert response =~ "Dostawa komputerów"
      refute response =~ "Usługi sprzątania"
    end

    test "filters by region", %{conn: conn} do
      create_tender_notice(%{
        object_id: "notice-1",
        order_object: "Dostawa do Warszawy",
        organization_name: "Urząd Mazowiecki",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_tender_notice(%{
        object_id: "notice-2",
        order_object: "Dostawa do Krakowa",
        organization_name: "Urząd Małopolski",
        organization_city: "Kraków",
        organization_province: "PL12",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      query_string = URI.encode_query([{"regions[]", "mazowieckie"}])
      conn = get(conn, "/tenders?" <> query_string)
      response = html_response(conn, 200)

      assert response =~ "Dostawa do Warszawy"
      refute response =~ "Dostawa do Krakowa"
    end

    test "filters by order type", %{conn: conn} do
      create_tender_notice(%{
        object_id: "notice-1",
        order_object: "Dostawa materiałów",
        organization_name: "Urząd Miasta",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_tender_notice(%{
        object_id: "notice-2",
        order_object: "Usługi transportowe",
        organization_name: "Urząd Gminy",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Services",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      query_string = URI.encode_query([{"order_types[]", "Delivery"}])
      conn = get(conn, "/tenders?" <> query_string)
      response = html_response(conn, 200)

      assert response =~ "Dostawa materiałów"
      refute response =~ "Usługi transportowe"
    end

    test "only shows ContractNotice type", %{conn: conn} do
      create_tender_notice(%{
        object_id: "notice-1",
        order_object: "Ogłoszenie o zamówieniu",
        organization_name: "Urząd Miasta",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_tender_notice(%{
        object_id: "notice-2",
        order_object: "Wynik postępowania",
        organization_name: "Urząd Gminy",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "TenderResultNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      conn = get(conn, ~p"/tenders")
      response = html_response(conn, 200)

      assert response =~ "Ogłoszenie o zamówieniu"
      refute response =~ "Wynik postępowania"
    end

    test "only shows notices with future submission date", %{conn: conn} do
      create_tender_notice(%{
        object_id: "notice-1",
        order_object: "Aktualny przetarg",
        organization_name: "Urząd Miasta",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_tender_notice(%{
        object_id: "notice-2",
        order_object: "Wygasły przetarg",
        organization_name: "Urząd Gminy",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), -1, :day)
      })

      conn = get(conn, ~p"/tenders")
      response = html_response(conn, 200)

      assert response =~ "Aktualny przetarg"
      refute response =~ "Wygasły przetarg"
    end

    test "supports pagination", %{conn: conn} do
      for i <- 1..25 do
        create_tender_notice(%{
          object_id: "notice-#{i}",
          order_object: "Przetarg nr #{i}",
          organization_name: "Urząd #{i}",
          organization_city: "Miasto",
          organization_province: "PL14",
          order_type: "Delivery",
          notice_type: "ContractNotice",
          submitting_offers_date: DateTime.add(DateTime.utc_now(), i, :day)
        })
      end

      conn = get(conn, ~p"/tenders")
      response = html_response(conn, 200)

      assert response =~ "Strona 1 z 2"
      assert response =~ "Następna"

      conn = get(conn, ~p"/tenders?page=2")
      response = html_response(conn, 200)

      assert response =~ "Strona 2 z 2"
      assert response =~ "Poprzednia"
    end

    test "filters by multiple regions", %{conn: conn} do
      create_tender_notice(%{
        object_id: "notice-1",
        order_object: "Przetarg mazowiecki",
        organization_name: "Urząd Mazowiecki",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_tender_notice(%{
        object_id: "notice-2",
        order_object: "Przetarg małopolski",
        organization_name: "Urząd Małopolski",
        organization_city: "Kraków",
        organization_province: "PL12",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_tender_notice(%{
        object_id: "notice-3",
        order_object: "Przetarg wielkopolski",
        organization_name: "Urząd Wielkopolski",
        organization_city: "Poznań",
        organization_province: "PL30",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      # Use proper query string encoding for arrays
      query_string = URI.encode_query([{"regions[]", "mazowieckie"}, {"regions[]", "malopolskie"}])
      conn = get(conn, "/tenders?" <> query_string)
      response = html_response(conn, 200)

      assert response =~ "Przetarg mazowiecki"
      assert response =~ "Przetarg małopolski"
      refute response =~ "Przetarg wielkopolski"
    end

    test "filters by multiple order types", %{conn: conn} do
      create_tender_notice(%{
        object_id: "notice-1",
        order_object: "Dostawa towarów",
        organization_name: "Urząd",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_tender_notice(%{
        object_id: "notice-2",
        order_object: "Świadczenie usług",
        organization_name: "Urząd",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Services",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_tender_notice(%{
        object_id: "notice-3",
        order_object: "Roboty budowlane",
        organization_name: "Urząd",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Works",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      # Use proper query string encoding for arrays
      query_string = URI.encode_query([{"order_types[]", "Delivery"}, {"order_types[]", "Services"}])
      conn = get(conn, "/tenders?" <> query_string)
      response = html_response(conn, 200)

      # Count tender cards to verify correct number of results
      card_count = response |> String.split("tender-card") |> length() |> Kernel.-(1)
      assert card_count == 2

      # Should include the filtered results
      assert response =~ "Dostawa towarów"
      assert response =~ "Świadczenie usług"
    end

    test "handles empty regions array", %{conn: conn} do
      create_tender_notice(%{
        order_object: "Test przetarg",
        organization_name: "Urząd",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      query_string = URI.encode_query([{"regions[]", ""}])
      conn = get(conn, "/tenders?" <> query_string)
      response = html_response(conn, 200)

      assert response =~ "Test przetarg"
    end

    test "handles empty order_types array", %{conn: conn} do
      create_tender_notice(%{
        order_object: "Test przetarg",
        organization_name: "Urząd",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      query_string = URI.encode_query([{"order_types[]", ""}])
      conn = get(conn, "/tenders?" <> query_string)
      response = html_response(conn, 200)

      assert response =~ "Test przetarg"
    end

    test "combines query, regions, and order_types filters", %{conn: conn} do
      create_tender_notice(%{
        object_id: "notice-1",
        order_object: "Dostawa komputerów do Warszawy",
        organization_name: "Urząd Mazowiecki",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_tender_notice(%{
        object_id: "notice-2",
        order_object: "Dostawa komputerów do Krakowa",
        organization_name: "Urząd Małopolski",
        organization_city: "Kraków",
        organization_province: "PL12",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_tender_notice(%{
        object_id: "notice-3",
        order_object: "Usługi komputerowe w Warszawie",
        organization_name: "Urząd Mazowiecki",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Services",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      query_string = URI.encode_query([{"q", "komputerów"}, {"regions[]", "mazowieckie"}, {"order_types[]", "Delivery"}])
      conn = get(conn, "/tenders?" <> query_string)
      response = html_response(conn, 200)

      assert response =~ "Dostawa komputerów do Warszawy"
      refute response =~ "Dostawa komputerów do Krakowa"
      refute response =~ "Usługi komputerowe w Warszawie"
    end
  end

  describe "alert selector visibility" do
    setup %{conn: conn} do
      # Create free user
      {:ok, %{user: free_user}} =
        PrzetargowyPrzeglad.Accounts.register_user(%{
          email: "free@example.com",
          password: "password123",
          tender_category: "Dostawy",
          region: "mazowieckie"
        })

      {:ok, verified_free} = PrzetargowyPrzeglad.Accounts.verify_user_email(free_user.email_verification_token)

      # Create premium user
      {:ok, %{user: premium_user}} =
        PrzetargowyPrzeglad.Accounts.register_premium_user(%{
          email: "premium@example.com",
          password: "password123",
          tender_category: "Usługi",
          region: "malopolskie",
          keyword: "test"
        })

      {:ok, verified_premium} = PrzetargowyPrzeglad.Accounts.verify_user_email(premium_user.email_verification_token)

      free_conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, verified_free.id)

      premium_conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, verified_premium.id)

      %{free_conn: free_conn, premium_conn: premium_conn}
    end

    test "does not show alert selector for unauthenticated users", %{conn: conn} do
      conn = get(conn, ~p"/tenders")
      response = html_response(conn, 200)

      refute response =~ "Zastosuj filtry z zapisanego alertu"
    end

    test "does not show alert selector for free users", %{free_conn: conn} do
      conn = get(conn, ~p"/tenders")
      response = html_response(conn, 200)

      refute response =~ "Zastosuj filtry z zapisanego alertu"
    end

    test "shows alert selector for paid users", %{premium_conn: conn} do
      conn = get(conn, ~p"/tenders")
      response = html_response(conn, 200)

      assert response =~ "Zastosuj filtry z zapisanego alertu"
    end
  end

  defp create_tender_notice(attrs) do
    default_attrs = %{
      object_id: "notice-#{:erlang.unique_integer([:positive])}",
      notice_number: "2024/BZP 00000001/01",
      bzp_number: "2024/BZP 00001234",
      client_type: "1.1.5",
      tender_type: "1.1.1",
      is_tender_amount_below_eu: true,
      publication_date: DateTime.utc_now(),
      cpv_codes: ["09100000-0"],
      procedure_result: nil,
      organization_country: "PL",
      organization_national_id: "1234567890",
      organization_id: "1234",
      tender_id: "ocds-148610-test-#{:erlang.unique_integer([:positive])}",
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
