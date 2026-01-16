defmodule PrzetargowyPrzegladWeb.Plugs.AdminAuthTest do
  use PrzetargowyPrzegladWeb.ConnCase, async: true

  alias PrzetargowyPrzegladWeb.Plugs.AdminAuth

  setup do
    # Store original config
    original_config = Application.get_env(:przetargowy_przeglad, :admin_auth)

    # Set test credentials
    Application.put_env(:przetargowy_przeglad, :admin_auth,
      username: "admin",
      password: "secret123"
    )

    on_exit(fn ->
      if original_config do
        Application.put_env(:przetargowy_przeglad, :admin_auth, original_config)
      else
        Application.delete_env(:przetargowy_przeglad, :admin_auth)
      end
    end)

    :ok
  end

  defp encode_credentials(username, password) do
    Base.encode64("#{username}:#{password}")
  end

  describe "init/1" do
    test "returns opts unchanged" do
      opts = [some: :option]
      assert AdminAuth.init(opts) == opts
    end
  end

  describe "call/2" do
    test "allows request with valid credentials" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Basic " <> encode_credentials("admin", "secret123"))
        |> AdminAuth.call([])

      refute conn.halted
      refute conn.status == 401
    end

    test "rejects request with invalid username" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Basic " <> encode_credentials("wrong", "secret123"))
        |> AdminAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end

    test "rejects request with invalid password" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Basic " <> encode_credentials("admin", "wrongpass"))
        |> AdminAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end

    test "rejects request without authorization header" do
      conn =
        build_conn()
        |> AdminAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end

    test "rejects request with non-Basic authorization" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer sometoken")
        |> AdminAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects request with invalid base64 encoding" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Basic not-valid-base64!!!")
        |> AdminAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "sets www-authenticate header on unauthorized response" do
      conn =
        build_conn()
        |> AdminAuth.call([])

      assert get_resp_header(conn, "www-authenticate") == [~s(Basic realm="Admin Area")]
    end

    test "handles credentials with colons in password" do
      # Password with colons should work since we split with parts: 2
      Application.put_env(:przetargowy_przeglad, :admin_auth,
        username: "admin",
        password: "pass:with:colons"
      )

      conn =
        build_conn()
        |> put_req_header(
          "authorization",
          "Basic " <> encode_credentials("admin", "pass:with:colons")
        )
        |> AdminAuth.call([])

      refute conn.halted
    end
  end
end
