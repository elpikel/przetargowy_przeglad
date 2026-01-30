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
    get "/login", SessionController, :show_login
    post "/create", SessionController, :create_session
    get "/register", UserController, :show_register
    get "/register/premium", UserController, :show_register_premium
    post "/register", UserController, :create_user
    post "/register/premium", UserController, :create_premium_user
    get "/registration-success", UserController, :registration_success
    get "/verify-email", UserController, :verify_email
    get "/tenders", TenderController, :index
  end

  scope "/", PrzetargowyPrzegladWeb do
    pipe_through [:browser, :require_auth]

    get "/dashboard", DashboardController, :show_dashboard
    post "/dashboard/alerts", DashboardController, :update_alert
    post "/dashboard/alerts/new", DashboardController, :create_alert
    delete "/dashboard/alerts/:id", DashboardController, :delete_alert
    post "/dashboard/password", DashboardController, :update_password
    get "/logout", SessionController, :logout
    delete "/user", UserController, :delete_user
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
    end
  end
end
