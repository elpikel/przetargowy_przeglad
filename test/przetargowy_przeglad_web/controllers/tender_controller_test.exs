defmodule PrzetargowyPrzegladWeb.TenderControllerTest do
  use PrzetargowyPrzegladWeb.ConnCase, async: true

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
      insert(:tender_notice,
        order_object: "Dostawa sprzętu komputerowego",
        organization_name: "Urząd Miasta Warszawa",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      )

      conn = get(conn, ~p"/tenders")
      response = html_response(conn, 200)

      assert response =~ "Dostawa sprzętu komputerowego"
      assert response =~ "Urząd Miasta Warszawa"
      assert response =~ "Warszawa"
    end

    test "filters by text query", %{conn: conn} do
      insert(:tender_notice, %{
        order_object: "Dostawa komputerów",
        organization_name: "Urząd Miasta",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      insert(:tender_notice, %{
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
      insert(:tender_notice, %{
        order_object: "Dostawa do Warszawy",
        organization_name: "Urząd Mazowiecki",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      insert(:tender_notice, %{
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
      insert(:tender_notice, %{
        order_object: "Dostawa materiałów",
        organization_name: "Urząd Miasta",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      insert(:tender_notice, %{
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
      insert(:tender_notice, %{
        order_object: "Ogłoszenie o zamówieniu",
        organization_name: "Urząd Miasta",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      insert(:tender_notice, %{
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
      insert(:tender_notice, %{
        order_object: "Aktualny przetarg",
        organization_name: "Urząd Miasta",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      insert(:tender_notice, %{
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
        insert(:tender_notice, %{
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
      insert(:tender_notice, %{
        order_object: "Przetarg mazowiecki",
        organization_name: "Urząd Mazowiecki",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      insert(:tender_notice, %{
        order_object: "Przetarg małopolski",
        organization_name: "Urząd Małopolski",
        organization_city: "Kraków",
        organization_province: "PL12",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      insert(:tender_notice, %{
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
      insert(:tender_notice, %{
        order_object: "Dostawa towarów do magazynu",
        organization_name: "Urząd Dostawy",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      insert(:tender_notice, %{
        order_object: "Świadczenie usług informatycznych",
        organization_name: "Urząd Usług",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Services",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      insert(:tender_notice, %{
        order_object: "Wykonanie robót budowlanych",
        organization_name: "Urząd Robót",
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

      # Should include the filtered results
      assert response =~ "Dostawa towarów do magazynu"
      assert response =~ "Świadczenie usług informatycznych"
      # Should not include the Works tender
      refute response =~ "Wykonanie robót budowlanych"
      refute response =~ "Urząd Robót"
    end

    test "handles empty regions array", %{conn: conn} do
      insert(:tender_notice, %{
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
      insert(:tender_notice, %{
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
      insert(:tender_notice, %{
        order_object: "Dostawa komputerów do Warszawy",
        organization_name: "Urząd Mazowiecki",
        organization_city: "Warszawa",
        organization_province: "PL14",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      insert(:tender_notice, %{
        order_object: "Dostawa komputerów do Krakowa",
        organization_name: "Urząd Małopolski",
        organization_city: "Kraków",
        organization_province: "PL12",
        order_type: "Delivery",
        notice_type: "ContractNotice",
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      insert(:tender_notice, %{
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
      free_user = insert(:verified_user, email: "free@example.com", subscription_plan: "free")

      # Create premium user
      premium_user = insert(:verified_premium_user, email: "premium@example.com")
      insert(:premium_alert, user: premium_user)

      free_conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, free_user.id)

      premium_conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, premium_user.id)

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

  describe "GET /tenders/:id" do
    test "renders tender detail page for valid bzp_number", %{conn: conn} do
      tender =
        insert(:tender_notice, %{
          order_object: "Dostawa sprzętu komputerowego",
          organization_name: "Urząd Miasta Warszawa",
          organization_city: "Warszawa",
          organization_province: "PL14",
          order_type: "Delivery",
          notice_type: "ContractNotice",
          submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
        })

      # Verify tender was inserted
      assert tender.bzp_number

      # Verify we can find it directly
      found_tender = PrzetargowyPrzeglad.Tenders.get_tender_by_bzp_number(tender.bzp_number)
      assert found_tender
      assert found_tender.bzp_number == tender.bzp_number

      # Call controller action directly instead of via HTTP
      conn = get(conn, ~p"/tenders/#{tender.object_id}")
      response = html_response(conn, 200)

      assert response =~ "Dostawa sprzętu komputerowego"
      assert response =~ "Urząd Miasta Warszawa"
      assert response =~ "Warszawa"
      assert response =~ tender.bzp_number
    end

    test "returns 404 for non-existent tender", %{conn: conn} do
      conn = get(conn, ~p"/tenders/2024-BZP-99999999")
      assert html_response(conn, 404)
    end

    test "shows active badge for active tender", %{conn: conn} do
      tender =
        insert(:tender_notice, %{
          order_object: "Aktywny przetarg",
          submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
        })

      conn = get(conn, ~p"/tenders/#{tender.object_id}")
      response = html_response(conn, 200)

      assert response =~ "Aktywny"
      refute response =~ "Termin minął"
    end

    test "shows expired badge for expired tender", %{conn: conn} do
      tender =
        insert(:tender_notice, %{
          order_object: "Wygasły przetarg",
          submitting_offers_date: DateTime.add(DateTime.utc_now(), -1, :day)
        })

      conn = get(conn, ~p"/tenders/#{tender.object_id}")
      response = html_response(conn, 200)

      assert response =~ "Termin minął"
      refute response =~ "tender-badge-active"
    end

    test "includes SEO meta tags", %{conn: conn} do
      tender =
        insert(:tender_notice, %{
          order_object: "Dostawa sprzętu",
          organization_name: "Urząd",
          submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
        })

      conn = get(conn, ~p"/tenders/#{tender.object_id}")
      response = html_response(conn, 200)

      assert response =~ ~s(<meta name="description")
      assert response =~ ~s(<link rel="canonical")
      assert response =~ "Dostawa sprzętu"
    end

    test "includes noindex meta tag for expired tender", %{conn: conn} do
      tender =
        insert(:tender_notice, %{
          order_object: "Wygasły przetarg",
          submitting_offers_date: DateTime.add(DateTime.utc_now(), -1, :day)
        })

      conn = get(conn, ~p"/tenders/#{tender.object_id}")
      response = html_response(conn, 200)

      assert response =~ ~s(<meta name="robots" content="noindex, follow")
    end

    test "does not include noindex for active tender", %{conn: conn} do
      tender =
        insert(:tender_notice, %{
          order_object: "Aktywny przetarg",
          submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
        })

      conn = get(conn, ~p"/tenders/#{tender.object_id}")
      response = html_response(conn, 200)

      refute response =~ ~s(<meta name="robots" content="noindex)
    end

    test "displays all tender details", %{conn: conn} do
      tender =
        insert(:tender_notice, %{
          order_object: "Dostawa komputerów",
          organization_name: "Urząd Miasta",
          organization_city: "Warszawa",
          organization_province: "PL14",
          order_type: "Delivery",
          notice_type: "ContractNotice",
          cpv_codes: ["30200000-1", "30213000-5"],
          estimated_value: Decimal.new("100000"),
          submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
        })

      conn = get(conn, ~p"/tenders/#{tender.object_id}")
      response = html_response(conn, 200)

      assert response =~ "Dostawa komputerów"
      assert response =~ "Urząd Miasta"
      assert response =~ "Warszawa"
      assert response =~ "Dostawy"
      assert response =~ "30200000-1"
      assert response =~ "30213000-5"
      assert response =~ "100 000"
    end

    test "includes breadcrumb navigation", %{conn: conn} do
      tender =
        insert(:tender_notice, %{
          order_object: "Test przetarg",
          submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
        })

      conn = get(conn, ~p"/tenders/#{tender.object_id}")
      response = html_response(conn, 200)

      assert response =~ "Strona główna"
      assert response =~ "Przetargi"
      assert response =~ "breadcrumb"
    end

    test "includes link to official documentation", %{conn: conn} do
      tender =
        insert(:tender_notice, %{
          tender_id: "ocds-148610-test-123",
          order_object: "Test przetarg",
          submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day)
        })

      conn = get(conn, ~p"/tenders/#{tender.object_id}")
      response = html_response(conn, 200)

      assert response =~ "ezamowienia.gov.pl"
      assert response =~ "ocds-148610-test-123"
    end
  end
end
