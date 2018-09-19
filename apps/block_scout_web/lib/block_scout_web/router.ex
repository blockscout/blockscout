defmodule BlockScoutWeb.Router do
  use BlockScoutWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader) end
  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api/v1", BlockScoutWeb.API.V1, as: :api_v1 do
    pipe_through(:api)

    get("/supply", SupplyController, :supply)
  end

  scope "/api", BlockScoutWeb.API.RPC do
    pipe_through(:api)

    alias BlockScoutWeb.API.RPC

    forward("/", RPCTranslator, %{
      "block" => RPC.BlockController,
      "account" => RPC.AddressController,
      "logs" => RPC.LogsController,
      "token" => RPC.TokenController,
      "stats" => RPC.StatsController,
      "contract" => RPC.ContractController,
      "transaction" => RPC.TransactionController
    })
  end

  scope "/", BlockScoutWeb do
    pipe_through(:browser)

    resources("/", ChainController, only: [:show], singleton: true, as: :chain)

    resources "/blocks", BlockController, only: [:index, :show] do
      resources("/transactions", BlockTransactionController, only: [:index], as: :transaction)
    end

    resources("/pending_transactions", PendingTransactionController, only: [:index])

    get("/txs", TransactionController, :index)
    get("/tx/:id", TransactionController, :show)
    get("/tx/:id/token_transfers", TransactionController, :show, as: :transaction_token_transfer)
    get("/tx/:id/internal_transactions", TransactionController, :show, as: :transaction_internal_transaction)
    get("/tx/:id/logs", TransactionController, :show, as: :transaction_log)

    #resources "/tx", TransactionController, only: [:show] do
    #  resources(
    #    "/internal_transactions",
    #    TransactionController,
    #    only: [:show],
    #    as: :internal_transaction
    #  )

    #  resources("/logs", TransactionController, only: [:show], as: :log)

    #  resources("/token_transfers", TransactionController, only: [:show], as: :token_transfer)
    #end



    get("/address/:id/transactions", AddressController, :show, as: :address_transaction)
    resources "/address", AddressController, only: [:show] do
      resources("/ajax/transactions", AddressTransactionController, only: [:index], as: :transaction_ajax)

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

      resources(
        "/tokens",
        AddressTokenController,
        only: [:index],
        as: :token
      )

      resources(
        "/token_balances",
        AddressTokenBalanceController,
        only: [:index],
        as: :token_balance
      )
    end

    resources "/tokens", Tokens.TokenController, only: [:show], as: :token do
      resources(
        "/read_contract",
        Tokens.ReadContractController,
        only: [:index],
        as: :read_contract
      )

      resources(
        "/token_holders",
        Tokens.HolderController,
        only: [:index],
        as: :holder
      )
    end

    resources(
      "/smart_contracts",
      SmartContractController,
      only: [:index, :show],
      as: :smart_contract
    )

    get("/search", ChainController, :search)

    get("/api_docs", APIDocsController, :index)
  end
end
