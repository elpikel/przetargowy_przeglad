defmodule PrzetargowyPrzeglad.Email.NewsletterEmail do
  import Swoosh.Email

  alias PrzetargowyPrzegladWeb.Endpoint

  @from {"Przetargowy Przegląd", "el.pikel@gmail.com"}

  def build(newsletter, subscriber) do
    new()
    |> to(subscriber.email)
    |> from(@from)
    |> subject(newsletter.subject)
    |> html_body(personalize(newsletter.content_html, subscriber))
    |> text_body(personalize(newsletter.content_text, subscriber))
  end

  defp personalize(content, subscriber) do
    content
    |> replace_placeholder("{{subscriber_name_greeting}}", name_greeting(subscriber))
    |> replace_placeholder("{{referral_code}}", Map.get(subscriber, :referral_code) || "BRAK")
    |> replace_placeholder("{{unsubscribe_url}}", unsubscribe_url(subscriber))
    |> replace_placeholder("{{preferences_url}}", preferences_url(subscriber))
  end

  defp replace_placeholder(content, placeholder, value) do
    String.replace(content, placeholder, value || "")
  end

  defp name_greeting(%{name: nil}), do: ""
  defp name_greeting(%{name: ""}), do: ""
  defp name_greeting(%{name: name}), do: " #{name}"

  defp unsubscribe_url(subscriber) do
    token = generate_token(subscriber.email)
    "#{Endpoint.url()}/unsubscribe?email=#{URI.encode(subscriber.email)}&token=#{token}"
  end

  defp preferences_url(subscriber) do
    token = generate_token(subscriber.email)
    "#{Endpoint.url()}/preferences?email=#{URI.encode(subscriber.email)}&token=#{token}"
  end

  defp generate_token(email) do
    secret = Application.get_env(:przetargowy_przeglad, :secret_key_base, "dev_secret")

    :crypto.mac(:hmac, :sha256, secret, email)
    |> Base.url_encode64(padding: false)
    |> String.slice(0, 16)
  end
end
