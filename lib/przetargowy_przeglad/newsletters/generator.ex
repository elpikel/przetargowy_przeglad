defmodule PrzetargowyPrzeglad.Newsletter.Generator do
  @moduledoc """
  Generuje treść newslettera na podstawie danych z ostatniego tygodnia.
  """

  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Tenders
  alias PrzetargowyPrzeglad.Newsletter.Newsletter

  import Ecto.Query

  require Logger

  @tips [
    "Zanim złożysz ofertę, sprawdź historię zamawiającego w BZP. Ile było ofert? Kto wygrywał? Za ile?",
    "Mniejsze gminy = mniejsza konkurencja. Średnio 3,2 oferty vs 8,4 w dużych miastach.",
    "Koniec kwartału to żniwa – instytucje muszą wydać budżety. Obserwuj marzec, czerwiec, wrzesień i grudzień.",
    "Nie startuj wszędzie. Wybierz 2-3 branże i buduj w nich reputację oraz referencje.",
    "Sprawdź CPV przetargu – podobne zamówienia mogą mieć różne kody, co zmniejsza konkurencję.",
    "Czytaj uważnie kryteria oceny. Czasem 'jakość' waży więcej niż cena – to Twoja szansa.",
    "Zamawiający często publikują podobne przetargi co roku. Śledź historię i przygotuj się wcześniej.",
    "Dołącz do branżowych grup i forów. Informacje o przetargach często pojawiają się tam szybciej."
  ]

  @doc """
  Generuje kompletny newsletter na bieżący tydzień.
  """
  def generate do
    Logger.info("Newsletter Generator: Starting generation")

    issue_number = next_issue_number()
    stats = Tenders.get_weekly_stats()
    top_tenders = Tenders.get_top_for_newsletter(5)
    tip = Enum.random(@tips)

    subject = build_subject(issue_number, stats)
    content_html = build_html(issue_number, stats, top_tenders, tip)
    content_text = build_text(issue_number, stats, top_tenders, tip)

    attrs = %{
      issue_number: issue_number,
      subject: subject,
      content_html: content_html,
      content_text: content_text,
      status: "generated",
      stats: stats,
      featured_tender_ids: Enum.map(top_tenders, & &1.id),
      scheduled_at: next_monday_8am()
    }

    %Newsletter{}
    |> Newsletter.changeset(attrs)
    |> Repo.insert()
  end

  def next_issue_number do
    case Repo.one(from n in Newsletter, select: max(n.issue_number)) do
      nil -> 1
      max -> max + 1
    end
  end

  defp next_monday_8am do
    today = Date.utc_today()

    days_until_monday =
      case Date.day_of_week(today) do
        # Jeśli dziś poniedziałek, to za tydzień
        1 -> 7
        n -> rem(8 - n, 7)
      end

    days_until_monday = if days_until_monday == 0, do: 7, else: days_until_monday

    next_monday = Date.add(today, days_until_monday)
    DateTime.new!(next_monday, ~T[08:00:00], "Etc/UTC")
  end

  defp build_subject(issue_number, stats) do
    value = format_value_short(stats.total_value)
    "🎯 Przetargowy Przegląd ##{issue_number} | #{value} w przetargach tego tygodnia"
  end

  defp build_html(issue_number, stats, top_tenders, tip) do
    """
    <!DOCTYPE html>
    <html lang="pl">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Przetargowy Przegląd ##{issue_number}</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif;
          line-height: 1.6;
          color: #1a1a1a;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          background: #f8fafc;
        }
        .container {
          background: white;
          border-radius: 12px;
          padding: 30px;
          box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        h1 {
          color: #0f172a;
          font-size: 28px;
          margin-bottom: 8px;
          border-bottom: 3px solid #3b82f6;
          padding-bottom: 12px;
        }
        h2 {
          color: #1e40af;
          font-size: 18px;
          margin-top: 32px;
          margin-bottom: 16px;
        }
        .stat-box {
          background: linear-gradient(135deg, #3b82f6, #1d4ed8);
          color: white;
          padding: 24px;
          border-radius: 12px;
          text-align: center;
          margin: 24px 0;
        }
        .stat-number {
          font-size: 42px;
          font-weight: 700;
          line-height: 1.2;
        }
        .stat-label {
          font-size: 14px;
          opacity: 0.9;
          margin-top: 8px;
        }
        .industries {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
          margin: 16px 0;
        }
        .industry-tag {
          background: #e0e7ff;
          color: #3730a3;
          padding: 4px 12px;
          border-radius: 20px;
          font-size: 13px;
        }
        .tender-card {
          background: #f8fafc;
          border-left: 4px solid #3b82f6;
          padding: 16px;
          margin: 16px 0;
          border-radius: 0 8px 8px 0;
        }
        .tender-title {
          font-weight: 600;
          color: #0f172a;
          margin-bottom: 8px;
          font-size: 15px;
        }
        .tender-meta {
          font-size: 13px;
          color: #64748b;
          line-height: 1.8;
        }
        .tender-value {
          color: #059669;
          font-weight: 600;
        }
        .tender-link {
          display: inline-block;
          margin-top: 8px;
          color: #3b82f6;
          text-decoration: none;
          font-size: 13px;
        }
        .tender-link:hover {
          text-decoration: underline;
        }
        .tip-box {
          background: #fef3c7;
          border: 1px solid #f59e0b;
          border-radius: 8px;
          padding: 16px;
          margin: 24px 0;
        }
        .tip-box strong {
          color: #92400e;
        }
        .cta-section {
          background: #f0f9ff;
          border-radius: 8px;
          padding: 20px;
          margin: 24px 0;
          text-align: center;
        }
        .referral-box {
          background: #f8fafc;
          border: 2px dashed #cbd5e1;
          border-radius: 8px;
          padding: 16px;
          margin: 24px 0;
          text-align: center;
        }
        .referral-code {
          font-family: monospace;
          font-size: 18px;
          font-weight: 600;
          color: #3b82f6;
          background: white;
          padding: 4px 12px;
          border-radius: 4px;
        }
        .footer {
          margin-top: 40px;
          padding-top: 20px;
          border-top: 1px solid #e2e8f0;
          font-size: 13px;
          color: #64748b;
          text-align: center;
        }
        .footer a {
          color: #3b82f6;
          text-decoration: none;
        }
        .footer a:hover {
          text-decoration: underline;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Przetargowy Przegląd ##{issue_number}</h1>

        <p>Cześć{{subscriber_name_greeting}}!</p>
        <p>Oto Twój cotygodniowy przegląd rynku przetargów. Zero lania wody, same konkrety.</p>

        #{build_stats_section_html(stats)}

        #{build_tenders_section_html(top_tenders)}

        #{build_tip_section_html(tip)}

        #{build_cta_section_html()}

        <div class="footer">
          <p>Do przyszłego tygodnia! 👋</p>
          <p style="margin-top: 16px;">
            <a href="{{unsubscribe_url}}">Wypisz się</a> &nbsp;|&nbsp;
            <a href="{{preferences_url}}">Zmień preferencje</a>
          </p>
          <p style="font-size: 11px; color: #94a3b8; margin-top: 16px;">
            Przetargowy Przegląd<br>
            Twój cotygodniowy przegląd przetargów publicznych
          </p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp build_stats_section_html(stats) do
    industries_html =
      stats.top_industries
      |> Enum.map(fn %{name: name, count: count} ->
        "<span class=\"industry-tag\">#{String.capitalize(name)}: #{count}</span>"
      end)
      |> Enum.join("\n")

    """
    <h2>📊 Liczba tygodnia</h2>
    <div class="stat-box">
      <div class="stat-number">#{format_value(stats.total_value)}</div>
      <div class="stat-label">łączna wartość #{stats.total_count} przetargów opublikowanych w tym tygodniu</div>
    </div>

    <p><strong>Top branże:</strong></p>
    <div class="industries">
      #{industries_html}
    </div>
    """
  end

  defp build_tenders_section_html(tenders) when length(tenders) == 0 do
    """
    <h2>🔥 Top przetargi tygodnia</h2>
    <p style="color: #64748b;">Brak przetargów spełniających kryteria w tym tygodniu.</p>
    """
  end

  defp build_tenders_section_html(tenders) do
    tenders_html =
      tenders
      |> Enum.with_index(1)
      |> Enum.map(fn {tender, idx} ->
        """
        <div class="tender-card">
          <div class="tender-title">#{idx}. #{truncate(tender.title, 100)}</div>
          <div class="tender-meta">
            📍 #{tender.contracting_authority_name || "Zamawiający nieznany"}<br>
            💰 Wartość: <span class="tender-value">#{format_value(tender.estimated_value)}</span><br>
            ⏰ Termin składania: #{format_date(tender.submission_deadline)}
          </div>
          #{if tender.url, do: "<a href=\"#{tender.url}\" class=\"tender-link\">Zobacz szczegóły →</a>", else: ""}
        </div>
        """
      end)
      |> Enum.join("\n")

    """
    <h2>🔥 Top #{length(tenders)} przetargów tygodnia</h2>
    #{tenders_html}
    """
  end

  defp build_tip_section_html(tip) do
    """
    <h2>💡 Tip tygodnia</h2>
    <div class="tip-box">
      <strong>Pro tip:</strong> #{tip}
    </div>
    """
  end

  defp build_cta_section_html do
    """
    <div class="cta-section">
      <h2 style="margin-top: 0;">🎯 Chcesz więcej?</h2>
      <p>Pracuję nad raportem <strong>„Mapa marż przetargowych 2025"</strong> – dowiesz się, gdzie w Polsce jest największa marża w Twojej branży.</p>
      <p>Chcesz dostać go jako pierwszy? <strong>Odpowiedz na tego maila słowem MAPA.</strong></p>
    </div>
    """
  end

  defp build_text(issue_number, stats, top_tenders, tip) do
    tenders_text =
      top_tenders
      |> Enum.with_index(1)
      |> Enum.map(fn {tender, idx} ->
        """
        #{idx}. #{truncate(tender.title, 80)}
           📍 #{tender.contracting_authority_name || "Nieznany"}
           💰 #{format_value(tender.estimated_value)}
           ⏰ Termin: #{format_date(tender.submission_deadline)}
           🔗 #{tender.url || "brak linku"}
        """
      end)
      |> Enum.join("\n")

    industries_text =
      stats.top_industries
      |> Enum.map(fn %{name: name, count: count} -> "• #{String.capitalize(name)}: #{count}" end)
      |> Enum.join("\n")

    """
    PRZETARGOWY PRZEGLĄD ##{issue_number}
    =====================================

    Cześć{{subscriber_name_greeting}}!

    Oto Twój cotygodniowy przegląd rynku przetargów.

    📊 LICZBA TYGODNIA
    ------------------
    #{format_value(stats.total_value)}
    Łączna wartość #{stats.total_count} przetargów tego tygodnia

    Top branże:
    #{industries_text}

    🔥 TOP #{length(top_tenders)} PRZETARGÓW TYGODNIA
    ------------------
    #{tenders_text}

    💡 TIP TYGODNIA
    ------------------
    #{tip}

    🎯 CHCESZ WIĘCEJ?
    ------------------
    Odpowiedz na tego maila słowem MAPA, żeby dostać jako pierwszy
    raport "Mapa marż przetargowych 2025".

    📬 POLEĆ ZNAJOMEMU
    ------------------
    Twój kod polecający: {{referral_code}}

    ------------------
    Do przyszłego tygodnia!

    Wypisz się: {{unsubscribe_url}}
    Zmień preferencje: {{preferences_url}}
    """
  end

  # Formatting helpers

  defp format_value(nil), do: "nieznana wartość"

  defp format_value(%Decimal{} = value) do
    value
    |> Decimal.round(0)
    |> Decimal.to_integer()
    |> format_number()
    |> Kernel.<>(" zł")
  end

  defp format_value(value) when is_number(value) do
    format_number(round(value)) <> " zł"
  end

  defp format_value_short(nil), do: "? zł"

  defp format_value_short(%Decimal{} = value) do
    int_value = value |> Decimal.round(0) |> Decimal.to_integer()

    cond do
      int_value >= 1_000_000_000 -> "#{Float.round(int_value / 1_000_000_000, 1)} mld zł"
      int_value >= 1_000_000 -> "#{Float.round(int_value / 1_000_000, 1)} mln zł"
      int_value >= 1_000 -> "#{Float.round(int_value / 1_000, 0)} tys. zł"
      true -> "#{int_value} zł"
    end
  end

  defp format_value_short(value) when is_number(value) do
    format_value_short(Decimal.new("#{value}"))
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1 ")
    |> String.reverse()
  end

  defp format_date(nil), do: "brak terminu"

  defp format_date(%DateTime{} = dt) do
    "#{String.pad_leading("#{dt.day}", 2, "0")}.#{String.pad_leading("#{dt.month}", 2, "0")}.#{dt.year}"
  end

  defp truncate(nil, _), do: ""
  defp truncate(text, max) when byte_size(text) <= max, do: text
  defp truncate(text, max), do: String.slice(text, 0, max - 3) <> "..."
end
