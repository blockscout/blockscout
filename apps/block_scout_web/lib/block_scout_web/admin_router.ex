defmodule BlockScoutWeb.AdminRouter do
  @moduledoc """
  Router for admin pages.
  """

  use BlockScoutWeb, :router

  alias BlockScoutWeb.Plug.FetchUserFromSession
  alias BlockScoutWeb.Plug.Admin.{CheckOwnerRegistered, RequireAdminRole}

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader)
  end

  pipeline :check_configured do
    plug(CheckOwnerRegistered)
  end

  pipeline :ensure_admin do
    plug(FetchUserFromSession)
    plug(RequireAdminRole)
  end

  scope "/setup", BlockScoutWeb.Admin do
    pipe_through([:browser])

    get("/", SetupController, :configure)
    post("/", SetupController, :configure_admin)
  end

  scope "/login", BlockScoutWeb.Admin do
    pipe_through([:browser, :check_configured])

    get("/", SessionController, :new)
    post("/", SessionController, :create)
  end

  scope "/", BlockScoutWeb.Admin do
    pipe_through([:browser, :check_configured, :ensure_admin])

    get("/", DashboardController, :index)
  end
end
