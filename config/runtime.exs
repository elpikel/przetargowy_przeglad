import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/przetargowy_przeglad start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :przetargowy_przeglad, PrzetargowyPrzegladWeb.Endpoint, server: true
end

config :przetargowy_przeglad, PrzetargowyPrzegladWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :przetargowy_przeglad, PrzetargowyPrzeglad.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  # ssl: true,
  # ssl_opts: [verify: :verify_none]

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host =
    System.get_env("PHX_HOST") ||
      raise "environment variable PHX_HOST is missing"

  port = String.to_integer(System.get_env("PORT") || "4000")

  # Use HTTPS scheme when PHX_SCHEME is "https", otherwise default to HTTP
  scheme = System.get_env("PHX_SCHEME", "http")
  url_port = if scheme == "https", do: 443, else: 80

  config :przetargowy_przeglad, PrzetargowyPrzegladWeb.Endpoint,
    url: [host: host, port: url_port, scheme: scheme],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true

  # Email configuration
  config :przetargowy_przeglad, PrzetargowyPrzeglad.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: System.get_env("SMTP_HOST") || raise("SMTP_HOST missing"),
    port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
    username: System.get_env("SMTP_USERNAME") || raise("SMTP_USERNAME missing"),
    password: System.get_env("SMTP_PASSWORD") || raise("SMTP_PASSWORD missing"),
    ssl: false,
    tls: :always,
    auth: :always

  # Admin auth
  config :przetargowy_przeglad, :admin_auth,
    username: System.get_env("ADMIN_USERNAME") || raise("ADMIN_USERNAME missing"),
    password: System.get_env("ADMIN_PASSWORD") || raise("ADMIN_PASSWORD missing")

  # Mail from address
  config :przetargowy_przeglad, :mail_from,
    address: System.get_env("MAIL_FROM_ADDRESS") || "newsletter@example.com",
    name: System.get_env("MAIL_FROM_NAME") || "Przetargowy Przegląd"
end
