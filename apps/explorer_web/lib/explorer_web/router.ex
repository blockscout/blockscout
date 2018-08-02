defmodule ExplorerWeb.Router do
  use ExplorerWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(ExplorerWeb.CSPHeader)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :set_locale do
    plug(SetLocale, gettext: ExplorerWeb.Gettext, default_locale: "en")
  end

  scope "/api/v1", ExplorerWeb.API.V1, as: :api_v1 do
    pipe_through(:api)

    get("/supply", SupplyController, :supply)
  end

  scope "/api", ExplorerWeb.API.RPC do
    pipe_through(:api)

    alias ExplorerWeb.API.RPC

    forward("/", RPCTranslator, %{
      "block" => RPC.BlockController,
      "account" => RPC.AddressController
    })
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
      resources(
        "/internal_transactions",
        TransactionInternalTransactionController,
        only: [:index],
        as: :internal_transaction
      )

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

      resources(
        "/contracts",
        AddressContractController,
        only: [:index],
        as: :contract
      )

      resources(
        "/contract_verifications",
        AddressContractVerificationController,
        only: [:new, :create],
        as: :verify_contract
      )

      resources(
        "/read_contract",
        AddressReadContractController,
        only: [:index, :show],
        as: :read_contract
      )
    end

    get("/search", ChainController, :search)

    get("/api_docs", APIDocsController, :index)
  end
end
