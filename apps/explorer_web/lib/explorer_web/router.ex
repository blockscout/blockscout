defmodule ExplorerWeb.Router do
  use ExplorerWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)

    plug(:put_secure_browser_headers, %{
      "content-security-policy" => "\
        default-src 'self';\
        script-src 'self' 'unsafe-inline' 'unsafe-eval';\
        style-src 'self' 'unsafe-inline' 'unsafe-eval';\
        img-src 'self' 'unsafe-inline' 'unsafe-eval' data:;\
        font-src 'self' 'unsafe-inline' 'unsafe-eval' data:;\
      "
    })
  end

  pipeline :set_locale do
    plug(SetLocale, gettext: ExplorerWeb.Gettext, default_locale: "en")
  end

  pipeline :exq do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)

    plug(:put_secure_browser_headers, %{
      "content-security-policy" => "\
        default-src 'self';\
        script-src 'self' 'unsafe-inline';\
        font-src 'self' fonts.gstatic.com;\
        style-src 'self' 'unsafe-inline' fonts.googleapis.com;\
      "
    })

    plug(ExqUi.RouterPlug, namespace: "exq")
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/exq", ExqUi do
    pipe_through(:exq)
    forward("/", RouterPlug.Router, :index)
  end

  scope "/", ExplorerWeb do
    pipe_through(:browser)
    pipe_through(:set_locale)
    resources("/", ChainController, only: [:show], singleton: true, as: :chain)
  end

  scope "/:locale", ExplorerWeb do
    pipe_through(:browser)
    pipe_through(:set_locale)
    resources("/", ChainController, only: [:show], singleton: true, as: :chain)

    resources "/blocks", BlockController, only: [:index, :show] do
      resources("/transactions", BlockTransactionController, only: [:index], as: :transaction)
    end

    resources("/pending_transactions", PendingTransactionController, only: [:index])

    resources "/transactions", TransactionController, only: [:index, :show] do
      resources("/logs", TransactionLogController, only: [:index], as: :log)
    end

    resources "/addresses", AddressController, only: [:show] do
      resources("/transactions", AddressTransactionController, only: [:index], as: :transaction)

      resources(
        "/internal_transactions",
        AddressInternalTransactionController,
        only: [:index],
        as: :internal_transaction
      )
    end

    get("/search", ChainController, :search)
  end
end
