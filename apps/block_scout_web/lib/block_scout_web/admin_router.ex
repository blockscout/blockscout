defmodule BlockScoutWeb.AdminRouter do
  @moduledoc """
  Router for admin pages.
  """

  use BlockScoutWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader)
  end
end
