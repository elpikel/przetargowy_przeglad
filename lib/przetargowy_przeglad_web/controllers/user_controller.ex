defmodule PrzetargowyPrzegladWeb.UserController do
  use PrzetargowyPrzegladWeb, :controller

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzegladWeb.UserController.RegistrationForm

  plug :put_layout, false
  plug :put_root_layout, false

  def delete_user(conn, _params) do
    case Accounts.delete_user(conn.assigns.current_user.id) do
      {:ok, _user} ->
        conn
        |> clear_session()
        |> redirect(to: ~p"/")

      {:error, _reason} ->
        conn
        |> clear_session()
        |> redirect(to: ~p"/")
    end
  end

  def show_register(conn, _params) do
    changeset = RegistrationForm.changeset(%RegistrationForm{}, %{})
    render(conn, :show_register, changeset: changeset)
  end

  def registration_success(conn, _params) do
    render(conn, :registration_success)
  end

  def verify_email(conn, %{"token" => token}) do
    case Accounts.verify_user_email(token) do
      {:ok, _user} ->
        redirect(conn, to: ~p"/login")

      {:error, _reason} ->
        redirect(conn, to: ~p"/")
    end
  end

  def verify_email(conn, _) do
    redirect(conn, to: ~p"/")
  end

  def create_user(conn, %{"registration_form" => registration_params}) do
    # First validate the form
    form_changeset = RegistrationForm.changeset(%RegistrationForm{}, registration_params)

    case Ecto.Changeset.apply_action(form_changeset, :insert) do
      {:ok, _registration_data} ->
        # Form is valid, now create user and alert in database
        case Accounts.register_user(registration_params) do
          {:ok, %{user: _user, alert: _alert}} ->
            redirect(conn, to: ~p"/registration-success")

          {:error, :user, changeset, _} ->
            # Convert Ecto changeset errors to form errors
            {:error, form_changeset} =
              form_changeset
              |> convert_user_errors_to_form(changeset)
              |> Ecto.Changeset.apply_action(:insert)

            render(conn, :show_register, changeset: form_changeset)

          {:error, :alert, _changeset, _} ->
            {:error, form_changeset} = Ecto.Changeset.apply_action(form_changeset, :insert)

            render(conn, :show_register, changeset: form_changeset)
        end

      {:error, changeset} ->
        render(conn, :show_register, changeset: changeset)
    end
  end

  # Helper function to convert user schema errors to form errors
  defp convert_user_errors_to_form(form_changeset, user_changeset) do
    # Check for email uniqueness error
    case Keyword.get(user_changeset.errors, :email) do
      {"ten adres e-mail jest już zarejestrowany", _} ->
        Ecto.Changeset.add_error(form_changeset, :email, "ten adres e-mail jest już zarejestrowany")

      _ ->
        form_changeset
    end
  end
end
