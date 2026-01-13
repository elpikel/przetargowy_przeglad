defmodule PrzetargowyPrzeglad.Email.ConfirmationEmail do
  import Swoosh.Email

  @from {"Przetargowy Przegląd", "newsletter@przetargi.pl"}

  def build(subscriber) do
    confirmation_url = build_confirmation_url(subscriber.confirmation_token)

    new()
    |> to(subscriber.email)
    |> from(@from)
    |> subject("Potwierdź zapis do Przetargowego Przeglądu")
    |> html_body(html_content(subscriber, confirmation_url))
    |> text_body(text_content(subscriber, confirmation_url))
  end

  defp build_confirmation_url(token) do
    PrzetargowyPrzegladWeb.Endpoint.url() <> "/confirm/#{token}"
  end

  defp html_content(subscriber, url) do
    name = subscriber.name || "Cześć"

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
    </head>
    <body style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h1 style="color: #1e40af;">Przetargowy Przegląd</h1>

      <p>#{name}!</p>

      <p>Dziękujemy za zapis do newslettera. Pozostał jeden krok – potwierdź swój email klikając w poniższy przycisk:</p>

      <p style="text-align: center; margin: 30px 0;">
        <a href="#{url}" style="background: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
          Potwierdzam zapis →
        </a>
      </p>

      <p style="color: #64748b; font-size: 14px;">
        Jeśli to nie Ty się zapisałeś, zignoruj tę wiadomość.
      </p>

      <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 30px 0;">

      <p style="color: #94a3b8; font-size: 12px;">
        Przetargowy Przegląd – Twój cotygodniowy przegląd przetargów publicznych
      </p>
    </body>
    </html>
    """
  end

  defp text_content(subscriber, url) do
    name = subscriber.name || "Cześć"

    """
    PRZETARGOWY PRZEGLĄD

    #{name}!

    Dziękujemy za zapis do newslettera. Potwierdź swój email klikając w link:

    #{url}

    Jeśli to nie Ty się zapisałeś, zignoruj tę wiadomość.

    --
    Przetargowy Przegląd
    """
  end
end
