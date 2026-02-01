defmodule PrzetargowyPrzeglad.Payments.PaymentEmail do
  @moduledoc """
  Composes payment-related emails for subscription notifications.
  """

  import Swoosh.Email

  @from {"Przetargowy Przegląd", "noreply@przetargowyprzeglad.pl"}

  @doc """
  Email sent after a successful payment.
  """
  def payment_successful(user, transaction) do
    new()
    |> to({user.email, user.email})
    |> from(@from)
    |> subject("Płatność zakończona pomyślnie - Przetargowy Przegląd")
    |> html_body("""
    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h1 style="color: #0a1628; font-size: 24px; margin-bottom: 20px;">Płatność zakończona pomyślnie</h1>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Dziękujemy za płatność! Twoja subskrypcja Premium została aktywowana.
      </p>

      <div style="background: #f0fdf4; border: 1px solid #16a34a; border-radius: 8px; padding: 16px; margin: 24px 0;">
        <p style="margin: 0; color: #166534;"><strong>Kwota:</strong> #{Decimal.round(transaction.amount, 2)} PLN</p>
        <p style="margin: 8px 0 0 0; color: #166534;"><strong>Typ:</strong> #{format_type(transaction.type)}</p>
      </div>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Możesz teraz korzystać z pełnego dostępu do wszystkich funkcji Premium, w tym nieograniczonych alertów,
        wielu regionów i własnych słów kluczowych.
      </p>

      <p style="color: #4a5568; font-size: 14px; margin-top: 24px;">
        Pozdrawiamy,<br>
        Zespół Przetargowy Przegląd
      </p>
    </div>
    """)
    |> text_body("""
    Płatność zakończona pomyślnie

    Dziękujemy za płatność! Twoja subskrypcja Premium została aktywowana.

    Kwota: #{Decimal.round(transaction.amount, 2)} PLN
    Typ: #{format_type(transaction.type)}

    Możesz teraz korzystać z pełnego dostępu do wszystkich funkcji Premium.

    Pozdrawiamy,
    Zespół Przetargowy Przegląd
    """)
  end

  @doc """
  Email sent after a failed payment.
  """
  def payment_failed(user, error_message) do
    new()
    |> to({user.email, user.email})
    |> from(@from)
    |> subject("Niepowodzenie płatności - Przetargowy Przegląd")
    |> html_body("""
    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h1 style="color: #dc2626; font-size: 24px; margin-bottom: 20px;">Niepowodzenie płatności</h1>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Niestety, nie udało się przetworzyć Twojej płatności za subskrypcję Premium.
      </p>

      <div style="background: #fef2f2; border: 1px solid #dc2626; border-radius: 8px; padding: 16px; margin: 24px 0;">
        <p style="margin: 0; color: #991b1b;"><strong>Powód:</strong> #{error_message || "Nieznany błąd"}</p>
      </div>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Spróbujemy ponowić płatność w ciągu najbliższych dni. Jeśli problem będzie się powtarzał,
        prosimy o sprawdzenie danych karty płatniczej lub skontaktowanie się z bankiem.
      </p>

      <p style="color: #4a5568; font-size: 14px; margin-top: 24px;">
        Pozdrawiamy,<br>
        Zespół Przetargowy Przegląd
      </p>
    </div>
    """)
    |> text_body("""
    Niepowodzenie płatności

    Niestety, nie udało się przetworzyć Twojej płatności za subskrypcję Premium.

    Powód: #{error_message || "Nieznany błąd"}

    Spróbujemy ponowić płatność w ciągu najbliższych dni.

    Pozdrawiamy,
    Zespół Przetargowy Przegląd
    """)
  end

  @doc """
  Email sent when a subscription is activated.
  """
  def subscription_activated(user) do
    new()
    |> to({user.email, user.email})
    |> from(@from)
    |> subject("Subskrypcja Premium aktywowana - Przetargowy Przegląd")
    |> html_body("""
    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h1 style="color: #16a34a; font-size: 24px; margin-bottom: 20px;">Witaj w Premium!</h1>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Twoja subskrypcja Premium została aktywowana. Dziękujemy za zaufanie!
      </p>

      <div style="background: #fdf8ed; border: 1px solid #c9a227; border-radius: 8px; padding: 16px; margin: 24px 0;">
        <h3 style="margin: 0 0 12px 0; color: #0a1628;">Co teraz możesz robić:</h3>
        <ul style="margin: 0; padding-left: 20px; color: #4a5568;">
          <li style="margin-bottom: 8px;">Tworzyć nieograniczoną liczbę alertów</li>
          <li style="margin-bottom: 8px;">Monitorować przetargi ze wszystkich regionów Polski</li>
          <li style="margin-bottom: 8px;">Filtrować przetargi według własnych słów kluczowych</li>
          <li>Wybierać dowolną kombinację branż</li>
        </ul>
      </div>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Twoja subskrypcja będzie automatycznie odnawiana co miesiąc.
        Możesz ją w dowolnym momencie anulować w ustawieniach konta.
      </p>

      <p style="color: #4a5568; font-size: 14px; margin-top: 24px;">
        Pozdrawiamy,<br>
        Zespół Przetargowy Przegląd
      </p>
    </div>
    """)
    |> text_body("""
    Witaj w Premium!

    Twoja subskrypcja Premium została aktywowana. Dziękujemy za zaufanie!

    Co teraz możesz robić:
    - Tworzyć nieograniczoną liczbę alertów
    - Monitorować przetargi ze wszystkich regionów Polski
    - Filtrować przetargi według własnych słów kluczowych
    - Wybierać dowolną kombinację branż

    Twoja subskrypcja będzie automatycznie odnawiana co miesiąc.

    Pozdrawiamy,
    Zespół Przetargowy Przegląd
    """)
  end

  @doc """
  Email sent when a subscription is cancelled.
  """
  def subscription_cancelled(user, subscription) do
    end_date = Calendar.strftime(subscription.current_period_end, "%d.%m.%Y")

    new()
    |> to({user.email, user.email})
    |> from(@from)
    |> subject("Subskrypcja anulowana - Przetargowy Przegląd")
    |> html_body("""
    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h1 style="color: #0a1628; font-size: 24px; margin-bottom: 20px;">Subskrypcja anulowana</h1>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Twoja subskrypcja Premium została anulowana zgodnie z Twoją prośbą.
      </p>

      <div style="background: #fffbeb; border: 1px solid #f59e0b; border-radius: 8px; padding: 16px; margin: 24px 0;">
        <p style="margin: 0; color: #92400e;">
          <strong>Ważne:</strong> Twój dostęp Premium pozostanie aktywny do <strong>#{end_date}</strong>.
          Po tej dacie Twoje konto zostanie automatycznie przekształcone w plan darmowy.
        </p>
      </div>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Jeśli zmienisz zdanie, możesz w każdej chwili ponownie wykupić subskrypcję Premium.
      </p>

      <p style="color: #4a5568; font-size: 14px; margin-top: 24px;">
        Pozdrawiamy,<br>
        Zespół Przetargowy Przegląd
      </p>
    </div>
    """)
    |> text_body("""
    Subskrypcja anulowana

    Twoja subskrypcja Premium została anulowana zgodnie z Twoją prośbą.

    Ważne: Twój dostęp Premium pozostanie aktywny do #{end_date}.
    Po tej dacie Twoje konto zostanie automatycznie przekształcone w plan darmowy.

    Jeśli zmienisz zdanie, możesz w każdej chwili ponownie wykupić subskrypcję Premium.

    Pozdrawiamy,
    Zespół Przetargowy Przegląd
    """)
  end

  @doc """
  Email sent when a subscription is about to expire.
  """
  def subscription_expiring_soon(user, subscription, days_left) do
    end_date = Calendar.strftime(subscription.current_period_end, "%d.%m.%Y")

    new()
    |> to({user.email, user.email})
    |> from(@from)
    |> subject("Twoja subskrypcja wkrótce wygaśnie - Przetargowy Przegląd")
    |> html_body("""
    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h1 style="color: #f59e0b; font-size: 24px; margin-bottom: 20px;">Subskrypcja wygasa za #{days_left} dni</h1>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Twoja subskrypcja Premium wygasa <strong>#{end_date}</strong>.
      </p>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Jeśli chcesz kontynuować korzystanie z funkcji Premium, upewnij się, że masz aktywną metodę płatności.
        Subskrypcja zostanie automatycznie odnowiona przed datą wygaśnięcia.
      </p>

      <p style="color: #4a5568; font-size: 14px; margin-top: 24px;">
        Pozdrawiamy,<br>
        Zespół Przetargowy Przegląd
      </p>
    </div>
    """)
    |> text_body("""
    Subskrypcja wygasa za #{days_left} dni

    Twoja subskrypcja Premium wygasa #{end_date}.

    Jeśli chcesz kontynuować korzystanie z funkcji Premium, upewnij się, że masz aktywną metodę płatności.

    Pozdrawiamy,
    Zespół Przetargowy Przegląd
    """)
  end

  @doc """
  Email sent when a subscription has expired.
  """
  def subscription_expired(user) do
    new()
    |> to({user.email, user.email})
    |> from(@from)
    |> subject("Subskrypcja wygasła - Przetargowy Przegląd")
    |> html_body("""
    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h1 style="color: #dc2626; font-size: 24px; margin-bottom: 20px;">Subskrypcja wygasła</h1>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Twoja subskrypcja Premium wygasła. Twoje konto zostało przekształcone w plan darmowy.
      </p>

      <div style="background: #f3f4f6; border-radius: 8px; padding: 16px; margin: 24px 0;">
        <p style="margin: 0; color: #4a5568;">
          W planie darmowym masz dostęp do jednego alertu z jednym regionem i jedną kategorią zamówień.
        </p>
      </div>

      <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">
        Chcesz wrócić do Premium? Możesz w każdej chwili ponownie wykupić subskrypcję i odzyskać pełny dostęp.
      </p>

      <p style="color: #4a5568; font-size: 14px; margin-top: 24px;">
        Pozdrawiamy,<br>
        Zespół Przetargowy Przegląd
      </p>
    </div>
    """)
    |> text_body("""
    Subskrypcja wygasła

    Twoja subskrypcja Premium wygasła. Twoje konto zostało przekształcone w plan darmowy.

    W planie darmowym masz dostęp do jednego alertu z jednym regionem i jedną kategorią zamówień.

    Chcesz wrócić do Premium? Możesz w każdej chwili ponownie wykupić subskrypcję.

    Pozdrawiamy,
    Zespół Przetargowy Przegląd
    """)
  end

  # Private helpers

  defp format_type("initial"), do: "Pierwsza płatność"
  defp format_type("renewal"), do: "Odnowienie subskrypcji"
  defp format_type("refund"), do: "Zwrot"
  defp format_type(_), do: "Płatność"
end
