defmodule PrzetargowyPrzeglad.Accounts.UserVerificationEmail do
  @moduledoc """
  Composes emails related to user accounts.
  """
  import Swoosh.Email

  alias PrzetargowyPrzeglad.Accounts.User

  @doc """
  Composes verification email.
  """
  def compose(%User{} = user, verification_url) do
    new()
    |> to({user.email, user.email})
    |> from({"Przetargowy Przegląd", "noreply@przetargowyprzeglad.pl"})
    |> subject("Potwierdź swój adres e-mail - Przetargowy Przegląd")
    |> html_body(verification_email_html(user, verification_url))
    |> text_body(verification_email_text(user, verification_url))
  end

  defp verification_email_html(_user, verification_url) do
    """
    <!DOCTYPE html>
    <html lang="pl">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            color: #0a1628;
            background-color: #fefcf8;
            margin: 0;
            padding: 0;
          }
          .container {
            max-width: 600px;
            margin: 40px auto;
            background: white;
            border-radius: 16px;
            box-shadow: 0 4px 16px rgba(10, 22, 40, 0.08);
            overflow: hidden;
          }
          .header {
            background: linear-gradient(135deg, #1a3052, #0a1628);
            color: #fefcf8;
            padding: 32px 40px;
            text-align: center;
          }
          .header h1 {
            margin: 0;
            font-size: 24px;
            font-weight: 700;
          }
          .content {
            padding: 40px;
          }
          .content p {
            margin: 0 0 16px;
            color: #4a5568;
          }
          .button {
            display: inline-block;
            margin: 24px 0;
            padding: 14px 32px;
            background: linear-gradient(135deg, #1a3052, #0a1628);
            color: white !important;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            text-align: center;
          }
          .footer {
            background: #fdf8ed;
            padding: 24px 40px;
            text-align: center;
            font-size: 14px;
            color: #4a5568;
          }
          .footer a {
            color: #1a3052;
            text-decoration: none;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Przetargowy Przegląd</h1>
          </div>
          <div class="content">
            <p>Witaj!</p>
            <p>Dziękujemy za rejestrację w serwisie <strong>Przetargowy Przegląd</strong>.</p>
            <p>Aby dokończyć proces rejestracji i aktywować swoje konto, kliknij w poniższy przycisk:</p>
            <p style="text-align: center;">
              <a href="#{verification_url}" class="button">Potwierdź adres e-mail</a>
            </p>
            <p style="font-size: 14px; color: #6b7280;">
              Jeśli przycisk nie działa, skopiuj i wklej poniższy link do przeglądarki:<br />
              <a href="#{verification_url}" style="color: #1a3052; word-break: break-all;">#{verification_url}</a>
            </p>
            <p style="margin-top: 32px; font-size: 14px; color: #6b7280;">
              Jeśli nie zakładałeś konta w naszym serwisie, zignoruj tę wiadomość.
            </p>
          </div>
          <div class="footer">
            <p>
              © #{DateTime.utc_now().year} Przetargowy Przegląd. Wszelkie prawa zastrzeżone.<br />
              <a href="mailto:kontakt@przetargowyprzeglad.pl">kontakt@przetargowyprzeglad.pl</a>
            </p>
          </div>
        </div>
      </body>
    </html>
    """
  end

  defp verification_email_text(_user, verification_url) do
    """
    Witaj!

    Dziękujemy za rejestrację w serwisie Przetargowy Przegląd.

    Aby dokończyć proces rejestracji i aktywować swoje konto, kliknij w poniższy link:

    #{verification_url}

    Jeśli nie zakładałeś konta w naszym serwisie, zignoruj tę wiadomość.

    ---
    Przetargowy Przegląd
    kontakt@przetargowyprzeglad.pl
    """
  end
end
