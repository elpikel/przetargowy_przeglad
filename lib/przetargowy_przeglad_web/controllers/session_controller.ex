defmodule PrzetargowyPrzegladWeb.SessionController do
  use PrzetargowyPrzegladWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzegladWeb.SessionController.LoginForm

  plug :put_layout, false
  plug :put_root_layout, false

  def show_login(conn, params) do
    # Store return_to in session if provided
    conn =
      if params["return_to"] do
        put_session(conn, :return_to, params["return_to"])
      else
        conn
      end

    changeset = LoginForm.changeset(%{})
    render(conn, :show_login, form: to_form(changeset, as: "session"))
  end

  def create_session(conn, %{"session" => session_params}) do
    changeset = LoginForm.changeset(session_params)

    if changeset.valid? do
      %{"email" => email, "password" => password} = session_params

      case Accounts.authenticate_user(email, password) do
        {:ok, user} ->
          return_to = get_session(conn, :return_to)

          conn
          |> put_session(:user_id, user.id)
          |> delete_session(:return_to)
          |> configure_session(renew: true)
          |> redirect(to: return_to || ~p"/dashboard")

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
