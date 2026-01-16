defmodule PrzetargowyPrzeglad.Email.NewsletterEmailTest do
  use ExUnit.Case, async: true

  alias PrzetargowyPrzeglad.Email.NewsletterEmail

  defp newsletter_fixture do
    %{
      subject: "🎯 Przetargowy Przegląd #1",
      content_html: """
      <p>Cześć{{subscriber_name_greeting}}!</p>
      <p>Twój kod: {{referral_code}}</p>
      <p><a href="{{unsubscribe_url}}">Wypisz się</a></p>
      <p><a href="{{preferences_url}}">Preferencje</a></p>
      """,
      content_text: """
      Cześć{{subscriber_name_greeting}}!
      Twój kod: {{referral_code}}
      Wypisz się: {{unsubscribe_url}}
      Preferencje: {{preferences_url}}
      """
    }
  end

  defp subscriber_fixture(overrides \\ %{}) do
    Map.merge(
      %{
        email: "test@example.com",
        name: "Jan",
        referral_code: "REF123"
      },
      overrides
    )
  end

  describe "build/2" do
    test "creates email with correct recipient" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture()

      email = NewsletterEmail.build(newsletter, subscriber)

      assert email.to == [{"", "test@example.com"}]
    end

    test "creates email with correct from address" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture()

      email = NewsletterEmail.build(newsletter, subscriber)

      assert email.from == {"Przetargowy Przegląd", "newsletter@przetargi.pl"}
    end

    test "creates email with correct subject" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture()

      email = NewsletterEmail.build(newsletter, subscriber)

      assert email.subject == "🎯 Przetargowy Przegląd #1"
    end

    test "personalizes name greeting in html body" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture(%{name: "Anna"})

      email = NewsletterEmail.build(newsletter, subscriber)

      assert email.html_body =~ "Cześć Anna!"
      refute email.html_body =~ "{{subscriber_name_greeting}}"
    end

    test "personalizes name greeting in text body" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture(%{name: "Anna"})

      email = NewsletterEmail.build(newsletter, subscriber)

      assert email.text_body =~ "Cześć Anna!"
      refute email.text_body =~ "{{subscriber_name_greeting}}"
    end

    test "handles nil name gracefully" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture(%{name: nil})

      email = NewsletterEmail.build(newsletter, subscriber)

      assert email.html_body =~ "Cześć!"
      refute email.html_body =~ "{{subscriber_name_greeting}}"
    end

    test "handles empty name gracefully" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture(%{name: ""})

      email = NewsletterEmail.build(newsletter, subscriber)

      assert email.html_body =~ "Cześć!"
    end

    test "includes referral code" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture(%{referral_code: "MYCODE123"})

      email = NewsletterEmail.build(newsletter, subscriber)

      assert email.html_body =~ "MYCODE123"
      assert email.text_body =~ "MYCODE123"
      refute email.html_body =~ "{{referral_code}}"
    end

    test "handles nil referral code" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture(%{referral_code: nil})

      email = NewsletterEmail.build(newsletter, subscriber)

      assert email.html_body =~ "BRAK"
    end

    test "includes unsubscribe url with email and token" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture(%{email: "user@test.com"})

      email = NewsletterEmail.build(newsletter, subscriber)

      assert email.html_body =~ "/unsubscribe?"
      assert email.html_body =~ "email=user"
      assert email.html_body =~ "token="
      refute email.html_body =~ "{{unsubscribe_url}}"
    end

    test "includes preferences url with email and token" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture(%{email: "user@test.com"})

      email = NewsletterEmail.build(newsletter, subscriber)

      assert email.html_body =~ "/preferences?"
      assert email.html_body =~ "email=user"
      assert email.html_body =~ "token="
      refute email.html_body =~ "{{preferences_url}}"
    end

    test "generates consistent tokens for same email" do
      newsletter = newsletter_fixture()
      subscriber = subscriber_fixture()

      email1 = NewsletterEmail.build(newsletter, subscriber)
      email2 = NewsletterEmail.build(newsletter, subscriber)

      # Extract tokens from unsubscribe URLs
      [_, token1] = Regex.run(~r/token=([^"&\s]+)/, email1.html_body)
      [_, token2] = Regex.run(~r/token=([^"&\s]+)/, email2.html_body)

      assert token1 == token2
    end
  end
end
