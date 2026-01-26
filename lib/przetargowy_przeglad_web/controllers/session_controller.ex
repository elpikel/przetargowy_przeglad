defmodule PrzetargowyPrzegladWeb.SessionController do
  use PrzetargowyPrzegladWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzegladWeb.SessionController.LoginForm

  plug :put_layout, false
  plug :put_root_layout, false

  def show_login(conn, _params) do
    changeset = LoginForm.changeset(%{})
    render(conn, :show_login, form: to_form(changeset, as: "session"))
  end

  def create_session(conn, %{"session" => session_params}) do
    changeset = LoginForm.changeset(session_params)

    if changeset.valid? do
      %{"email" => email, "password" => password} = session_params

      case Accounts.authenticate_user(email, password) do
        {:ok, user} ->
          conn
          |> put_session(:user_id, user.id)
          |> configure_session(renew: true)
          |> redirect(to: ~p"/dashboard")

        {:error, :invalid_credentials} ->
          changeset =
            changeset
            |> LoginForm.add_credentials_error()
            |> Map.put(:action, :validate)

          render(conn, :show_login, form: to_form(changeset, as: "session"))
      end
    else
      changeset = Map.put(changeset, :action, :validate)
      render(conn, :show_login, form: to_form(changeset, as: "session"))
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/")
  end
end
