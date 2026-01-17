defmodule PrzetargowyPrzegladWeb.Admin.DashboardLive do
  use PrzetargowyPrzegladWeb, :live_view

  alias PrzetargowyPrzeglad.Subscribers
  alias PrzetargowyPrzeglad.Tenders
  alias PrzetargowyPrzeglad.Newsletters

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Odświeżanie co 30 sekund
      :timer.send_interval(30_000, self(), :refresh)
    end

    {:ok, assign_stats(socket)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, assign_stats(socket)}
  end

  defp assign_stats(socket) do
    subscriber_stats = Subscribers.get_stats()
    tender_stats = Tenders.get_weekly_stats()
    newsletter_stats = get_newsletter_stats()
    recent_subscribers = Subscribers.list_recent(5)

    socket
    |> assign(:current_page, :dashboard)
    |> assign(:subscriber_stats, subscriber_stats)
    |> assign(:tender_stats, tender_stats)
    |> assign(:newsletter_stats, newsletter_stats)
    |> assign(:recent_subscribers, recent_subscribers)
    |> assign(:last_updated, DateTime.utc_now())
  end

  defp get_newsletter_stats do
    %{
      total: Newsletters.count_all(),
      sent: Newsletters.count_by_status("sent"),
      last_sent: Newsletters.get_last_sent(),
      next_scheduled: Newsletters.get_next_scheduled()
    }
  end

  defp format_value(nil), do: "0 zł"

  defp format_value(%Decimal{} = value) do
    value
    |> Decimal.round(0)
    |> Decimal.to_integer()
    |> format_number()
    |> Kernel.<>(" zł")
  end

  defp format_number(n) when n >= 1_000_000_000, do: "#{Float.round(n / 1_000_000_000, 1)} mld"
  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)} mln"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 0)} tys."
  defp format_number(n), do: "#{n}"

  defp format_date(nil), do: "-"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d.%m.%Y %H:%M")
  end

  defp format_relative_time(datetime) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "przed chwilą"
      diff < 3600 -> "#{div(diff, 60)} min temu"
      diff < 86400 -> "#{div(diff, 3600)} godz. temu"
      diff < 604_800 -> "#{div(diff, 86400)} dni temu"
      true -> Calendar.strftime(datetime, "%d.%m")
    end
  end

  defp max_industry_count([]), do: 1

  defp max_industry_count(industries) do
    industries |> Enum.map(& &1.count) |> Enum.max()
  end
end
