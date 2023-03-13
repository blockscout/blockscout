defmodule EventStream.Router do
  use EventStream, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {EventStream.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", EventStream do
    pipe_through(:browser)

    live("/", PageLive, :index)
    live("/received", ReceivedLive, :index)
    live("/published", PublishedLive, :index)
    get("/publisher", PublisherController, :stats)

    get("/ready", HealthController, :ready)
    get("/live", HealthController, :live)
  end

  # Other scopes may use custom stacks.
  # scope "/api", EventStream do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  import Phoenix.LiveDashboard.Router

  scope "/" do
    pipe_through(:browser)
    live_dashboard("/dashboard", metrics: EventStream.Metrics)
  end
end
