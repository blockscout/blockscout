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

  scope "/", BlockScoutWeb.Admin do
    pipe_through([:browser])

    get("/setup", SetupController, :configure)
    post("/setup", SetupController, :configure_admin)
  end

  scope "/", BlockScoutWeb.Admin do
    pipe_through([:browser, :check_configured])

    get("/login", SessionController, :new)
    post("/login", SessionController, :create)
  end

  scope "/", BlockScoutWeb.Admin do
    pipe_through([:browser, :check_configured, :ensure_admin])

    get("/", DashboardController, :index)
  end
end
