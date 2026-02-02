defmodule PrzetargowyPrzegladWeb.SEO do
  @moduledoc """
  Helpers for generating SEO meta tags.
  """

  @default_title "Przetargowy Przegląd - Portal Przetargów Publicznych"
  @default_description "Wyszukuj i monitoruj przetargi publiczne z całej Polski. Otrzymuj powiadomienia o nowych ogłoszeniach dopasowanych do Twojej branży i regionu."
  @default_image_url "https://przetargowyprzeglad.pl/og-image.jpg"
  @site_name "Przetargowy Przegląd"
  @twitter_handle "@przetargowy_pl"

  def meta_tags(assigns) do
    title = assigns[:page_title] || @default_title
    description = assigns[:page_description] || @default_description
    image = assigns[:page_image] || @default_image_url
    url = assigns[:canonical_url] || canonical_url(assigns[:conn])
    type = assigns[:page_type] || "website"

    [
      # Basic meta tags
      {:meta, [name: "description", content: description]},
      {:meta, [name: "keywords", content: keywords(assigns)]},
      {:meta, [name: "author", content: @site_name]},
      {:meta, [name: "robots", content: robots(assigns)]},

      # Canonical URL
      {:link, [rel: "canonical", href: url]},

      # Open Graph
      {:meta, [property: "og:title", content: title]},
      {:meta, [property: "og:description", content: description]},
      {:meta, [property: "og:type", content: type]},
      {:meta, [property: "og:url", content: url]},
      {:meta, [property: "og:image", content: image]},
      {:meta, [property: "og:site_name", content: @site_name]},
      {:meta, [property: "og:locale", content: "pl_PL"]},

      # Twitter Card
      {:meta, [name: "twitter:card", content: "summary_large_image"]},
      {:meta, [name: "twitter:site", content: @twitter_handle]},
      {:meta, [name: "twitter:title", content: title]},
      {:meta, [name: "twitter:description", content: description]},
      {:meta, [name: "twitter:image", content: image]}
    ]
  end

  defp canonical_url(conn) do
    if conn do
      scheme = if conn.scheme == :https, do: "https", else: "http"
      host = conn.host
      port = if conn.port in [80, 443], do: "", else: ":#{conn.port}"
      path = conn.request_path
      "#{scheme}://#{host}#{port}#{path}"
    else
      "https://przetargowyprzeglad.pl"
    end
  end

  defp keywords(assigns) do
    default_keywords = "przetargi publiczne, zamówienia publiczne, ogłoszenia przetargowe, BZP, tender, przetargi online"

    assigns[:keywords] || default_keywords
  end

  defp robots(assigns) do
    if assigns[:noindex] do
      "noindex, nofollow"
    else
      "index, follow"
    end
  end

  def structured_data_organization do
    %{
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => @site_name,
      "url" => "https://przetargowyprzeglad.pl",
      "logo" => "https://przetargowyprzeglad.pl/logo.png",
      "description" => @default_description,
      "address" => %{
        "@type" => "PostalAddress",
        "addressCountry" => "PL"
      },
      "contactPoint" => %{
        "@type" => "ContactPoint",
        "contactType" => "customer service",
        "email" => "kontakt@przetargowyprzeglad.pl"
      }
    }
  end

  def structured_data_tender(notice) do
    %{
      "@context" => "https://schema.org",
      "@type" => "GovernmentService",
      "name" => notice.order_object,
      "description" => notice.order_object,
      "provider" => %{
        "@type" => "GovernmentOrganization",
        "name" => notice.organization_name,
        "address" => %{
          "@type" => "PostalAddress",
          "addressLocality" => notice.organization_city,
          "addressCountry" => "PL"
        }
      },
      "areaServed" => %{
        "@type" => "Country",
        "name" => "Poland"
      },
      "availableChannel" => %{
        "@type" => "ServiceChannel",
        "serviceUrl" => "https://przetargowyprzeglad.pl/tenders"
      }
    }
  end

  def structured_data_breadcrumb(items) do
    list_items =
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {{name, url}, position} ->
        %{
          "@type" => "ListItem",
          "position" => position,
          "name" => name,
          "item" => url
        }
      end)

    %{
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => list_items
    }
  end
end
