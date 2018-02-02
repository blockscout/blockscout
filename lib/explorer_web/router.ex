defmodule ExplorerWeb.Router do
  use ExplorerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{
      "content-security-policy" => "\
        default-src 'self';\
        script-src 'self' 'unsafe-inline' 'unsafe-eval';\
        style-src 'self' 'unsafe-inline' 'unsafe-eval';\
        font-src 'self' 'unsafe-inline' 'unsafe-eval' data:;\
      "
    }
    if Mix.env != :prod, do: plug Jasmine, js_files: ["js/test.js"]
    plug SetLocale, gettext: ExplorerWeb.Gettext, default_locale: "en"
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ExplorerWeb do
    pipe_through :browser
    resources "/", ChainController, only: [:show], singleton: true, as: :chain
  end

  scope "/:locale", ExplorerWeb do
    pipe_through :browser # Use the default browser stack
    resources "/", ChainController, only: [:show], singleton: true, as: :chain
    resources "/blocks", BlockController, only: [:index, :show]
    resources "/transactions", TransactionController, only: [:index, :show]
    resources "/addresses", AddressController, only: [:show]
  end
end
