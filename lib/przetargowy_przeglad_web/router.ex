defmodule PrzetargowyPrzegladWeb.Router do
  use PrzetargowyPrzegladWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PrzetargowyPrzegladWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_auth do
    plug PrzetargowyPrzegladWeb.Plugs.RequireAuth
  end

  scope "/", PrzetargowyPrzegladWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/rules", PageController, :rules
    get "/privacy-policy", PageController, :privacy_policy
    get "/sitemap.xml", SitemapController, :index
    get "/login", SessionController, :show_login
    post "/create", SessionController, :create_session
    get "/register", UserController, :show_register
    post "/register", UserController, :create_user
    get "/registration-success", UserController, :registration_success
    get "/verify-email", UserController, :verify_email
    get "/tenders", TenderController, :index
    get "/tenders/:id", TenderController, :show
    get "/reports", ReportController, :index
    get "/reports/:slug", ReportController, :show
  end

  scope "/", PrzetargowyPrzegladWeb do
    pipe_through [:browser, :require_auth]

    # Alert creation from tender search (for free users)
    post "/tenders/create-alert", TenderController, :create_alert

    get "/dashboard", DashboardController, :show_dashboard
    post "/dashboard/alerts", DashboardController, :update_alert
    post "/dashboard/alerts/new", DashboardController, :create_alert
    delete "/dashboard/alerts/:id", DashboardController, :delete_alert
    post "/dashboard/password", DashboardController, :update_password

    # Subscription management
    get "/dashboard/subscription", SubscriptionController, :show
    get "/dashboard/subscription/new", SubscriptionController, :new
    post "/dashboard/subscription", SubscriptionController, :create
    delete "/dashboard/subscription", SubscriptionController, :cancel
    post "/dashboard/subscription/reactivate", SubscriptionController, :reactivate
    get "/dashboard/subscription/success", SubscriptionController, :payment_success
    get "/dashboard/subscription/error", SubscriptionController, :payment_error

    get "/logout", SessionController, :logout
    delete "/user", UserController, :delete_user
  end

  # Webhook endpoints (no CSRF protection)
  scope "/webhooks", PrzetargowyPrzegladWeb do
    pipe_through :api

    post "/stripe", WebhookController, :stripe
  end

  # Other scopes may use custom stacks.
  # scope "/api", PrzetargowyPrzegladWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:przetargowy_przeglad, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PrzetargowyPrzegladWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview

      # Development-only Stripe simulator
      get "/stripe/checkout", PrzetargowyPrzegladWeb.DevStripeController, :checkout
      post "/stripe/simulate-payment", PrzetargowyPrzegladWeb.DevStripeController, :simulate_payment
    end
  end
end
