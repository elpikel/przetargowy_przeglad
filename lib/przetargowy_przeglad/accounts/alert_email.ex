defmodule PrzetargowyPrzeglad.Accounts.AlertEmail do
  @moduledoc """
  Composes alert emails with tender notices.
  """
  import Swoosh.Email

  @doc """
  Composes email with tender notices for a user.
  """
  def compose(email, notices, tender_category) do
    new()
    |> to({email, email})
    |> from({"Przetargowy Przegląd", "noreply@przetargowyprzeglad.pl"})
    |> subject("Nowe przetargi: #{tender_category} - Przetargowy Przegląd")
    |> html_body(alert_email_html(notices, tender_category))
    |> text_body(alert_email_text(notices, tender_category))
  end

  defp alert_email_html(notices, tender_category) do
    notices_html = Enum.map_join(notices, "\n", &notice_html/1)

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
          .header p {
            margin: 8px 0 0;
            opacity: 0.9;
            font-size: 14px;
          }
          .content {
            padding: 32px 40px;
          }
          .content > p {
            margin: 0 0 24px;
            color: #4a5568;
          }
          .notice {
            border: 1px solid #f3e4c3;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 16px;
            background: #fefcf8;
          }
          .notice:last-child {
            margin-bottom: 0;
          }
          .notice-title {
            font-weight: 600;
            color: #0a1628;
            margin: 0 0 12px;
            font-size: 15px;
            line-height: 1.4;
          }
          .notice-meta {
            font-size: 13px;
            color: #4a5568;
            margin: 0;
          }
          .notice-meta strong {
            color: #1a3052;
          }
          .notice-deadline {
            display: inline-block;
            margin-top: 12px;
            padding: 6px 12px;
            background: #c9a227;
            color: #0a1628;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 600;
          }
          .notice-value {
            display: inline-block;
            margin-top: 8px;
            margin-left: 8px;
            padding: 6px 12px;
            background: #e8f5e9;
            color: #2e7d32;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 600;
          }
          .notice-link {
            display: inline-block;
            margin-top: 12px;
            color: #1a3052;
            text-decoration: none;
            font-size: 13px;
            font-weight: 500;
          }
          .notice-link:hover {
            text-decoration: underline;
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
          .unsubscribe {
            margin-top: 16px;
            font-size: 12px;
            color: #6b7280;
          }
          .unsubscribe a {
            color: #6b7280;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Przetargowy Przegląd</h1>
            <p>Twoje codzienne powiadomienie o przetargach</p>
          </div>
          <div class="content">
            <p>Znaleźliśmy <strong>#{length(notices)}</strong> przetargów w kategorii <strong>#{tender_category}</strong> oczekujących na oferty:</p>
            #{notices_html}
          </div>
          <div class="footer">
            <p>
              © #{DateTime.utc_now().year} Przetargowy Przegląd. Wszelkie prawa zastrzeżone.<br />
              <a href="mailto:kontakt@przetargowyprzeglad.pl">kontakt@przetargowyprzeglad.pl</a>
            </p>
            <p class="unsubscribe">
              Aby zmienić preferencje powiadomień, <a href="https://przetargowyprzeglad.pl/login">zaloguj się do swojego konta</a>.
            </p>
          </div>
        </div>
      </body>
    </html>
    """
  end

  defp notice_html(notice) do
    deadline = format_date(notice.submitting_offers_date)

    value_html =
      if notice.estimated_value,
        do: ~s(<span class="notice-value">#{format_value(notice.estimated_value)} PLN</span>),
        else: ""

    bzp_link = "https://ezamowienia.gov.pl/mp-client/search/list/#{notice.tender_id}"

    """
    <div class="notice">
      <p class="notice-title">#{truncate(notice.order_object, 200)}</p>
      <p class="notice-meta">
        <strong>#{notice.organization_name}</strong><br />
        #{notice.organization_city}
      </p>
      <span class="notice-deadline">Termin: #{deadline}</span>
      #{value_html}
      <br />
      <a href="#{bzp_link}" class="notice-link">Zobacz szczegóły →</a>
    </div>
    """
  end

  defp alert_email_text(notices, tender_category) do
    notices_text = Enum.map_join(notices, "\n\n---\n\n", &notice_text/1)

    """
    PRZETARGOWY PRZEGLĄD
    Twoje codzienne powiadomienie o przetargach

    Znaleźliśmy #{length(notices)} przetargów w kategorii #{tender_category} oczekujących na oferty:

    #{notices_text}

    ---
    Przetargowy Przegląd
    kontakt@przetargowyprzeglad.pl

    Aby zmienić preferencje powiadomień, zaloguj się do swojego konta: https://przetargowyprzeglad.pl/login
    """
  end

  defp notice_text(notice) do
    deadline = format_date(notice.submitting_offers_date)
    value_text = if notice.estimated_value, do: "Wartość: #{format_value(notice.estimated_value)} PLN\n", else: ""
    bzp_link = "https://ezamowienia.gov.pl/mo-public-board/notice/#{notice.bzp_number}"

    """
    #{truncate(notice.order_object, 200)}

    Zamawiający: #{notice.organization_name}
    Miejsce: #{notice.organization_city}
    Termin składania ofert: #{deadline}
    #{value_text}
    Link: #{bzp_link}
    """
  end

  defp format_date(nil), do: "Brak daty"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d.%m.%Y %H:%M")
  end

  defp format_value(nil), do: "-"

  defp format_value(value) do
    value
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1 ")
  end

  defp truncate(nil, _length), do: ""
  defp truncate(string, length) when byte_size(string) <= length, do: string

  defp truncate(string, length) do
    String.slice(string, 0, length) <> "..."
  end
end
