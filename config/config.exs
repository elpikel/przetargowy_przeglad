# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  przetargowy_przeglad: [
    args:
      ~w(js/app.js css/app.css --bundle --target=es2022 --outdir=../priv/static/assets --outbase=. --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :przetargowy_przeglad, Oban,
  engine: Oban.Engines.Basic,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", PrzetargowyPrzeglad.Workers.FetchTendersNotices, args: %{"days" => 60}},
       {"0 6 * * *", PrzetargowyPrzeglad.Workers.SendAlerts},
       # Stripe handles subscription renewals automatically via webhooks
       # This worker expires subscriptions that weren't renewed (backup for webhook failures)
       {"0 4 * * *", PrzetargowyPrzeglad.Workers.ExpireSubscriptions},
       # Monthly reports - run on 1st of month at 2 AM
       {"0 2 1 * *", PrzetargowyPrzeglad.Workers.GenerateMonthlyReports}
     ]}
  ],
  queues: [default: 10, mailers: 20, tenders: 1, alerts: 1, payments: 5],
  repo: PrzetargowyPrzeglad.Repo

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :przetargowy_przeglad, PrzetargowyPrzeglad.Mailer, adapter: Swoosh.Adapters.Local

# Configure the endpoint
config :przetargowy_przeglad, PrzetargowyPrzegladWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PrzetargowyPrzegladWeb.ErrorHTML, json: PrzetargowyPrzegladWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PrzetargowyPrzeglad.PubSub,
  live_view: [signing_salt: "iPfNmzYb"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
config :przetargowy_przeglad,
  ecto_repos: [PrzetargowyPrzeglad.Repo],
  generators: [timestamp_type: :utc_datetime]

import_config "#{config_env()}.exs"
