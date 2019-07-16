defmodule BlockScoutApi.Router do
  use BlockScoutApi, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", BlockScoutApi do
    pipe_through :api
  end
end
