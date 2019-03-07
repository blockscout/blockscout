defmodule BlockScoutWeb.Router do
  use BlockScoutWeb, :router

  alias BlockScoutWeb.Plug.GraphQL

  forward("/wobserver", Wobserver.Web.Router)
  forward("/admin", BlockScoutWeb.AdminRouter)

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader)
  end

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

  # Needs to be 200 to support the schema introspection for graphiql
  @max_complexity 200

  forward("/graphql", Absinthe.Plug,
    schema: BlockScoutWeb.Schema,
    analyze_complexity: true,
    max_complexity: @max_complexity
  )

  forward("/graphiql", Absinthe.Plug.GraphiQL,
    schema: BlockScoutWeb.Schema,
    interface: :advanced,
    default_query: GraphQL.default_query(),
    socket: BlockScoutWeb.UserSocket,
    analyze_complexity: true,
    max_complexity: @max_complexity
  )

  # Disallows Iframes (write routes)
  scope "/", BlockScoutWeb do
    pipe_through(:browser)
  end

  # Allows Iframes (read-only routes)
  scope "/", BlockScoutWeb do
    pipe_through([:browser, BlockScoutWeb.Plug.AllowIframe])

    resources("/", ChainController, only: [:show], singleton: true, as: :chain)

    resources("/market_history_chart", Chain.MarketHistoryChartController, only: [:show], singleton: true)

    resources "/blocks", BlockController, only: [:index, :show], param: "hash_or_number" do
      resources("/transactions", BlockTransactionController, only: [:index], as: :transaction)
    end

    get("/reorgs", BlockController, :reorg, as: :reorg)

    get("/uncles", BlockController, :uncle, as: :uncle)

    resources("/pending_transactions", PendingTransactionController, only: [:index])

    resources("/recent_transactions", RecentTransactionsController, only: [:index])

    get("/txs", TransactionController, :index)

    resources "/tx", TransactionController, only: [:show] do
      resources(
        "/internal_transactions",
        TransactionInternalTransactionController,
        only: [:index],
        as: :internal_transaction
      )

      resources("/logs", TransactionLogController, only: [:index], as: :log)

      resources("/token_transfers", TransactionTokenTransferController,
        only: [:index],
        as: :token_transfer
      )
    end

    resources("/accounts", AddressController, only: [:index])

    resources "/address", AddressController, only: [:show] do
      resources("/transactions", AddressTransactionController, only: [:index], as: :transaction)

      resources(
        "/internal_transactions",
        AddressInternalTransactionController,
        only: [:index],
        as: :internal_transaction
      )

      resources(
        "/validations",
        AddressValidationController,
        only: [:index],
        as: :validation
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

      resources("/tokens", AddressTokenController, only: [:index], as: :token) do
        resources(
          "/token_transfers",
          AddressTokenTransferController,
          only: [:index],
          as: :transfers
        )
      end

      resources(
        "/token_balances",
        AddressTokenBalanceController,
        only: [:index],
        as: :token_balance
      )

      resources(
        "/coin_balances",
        AddressCoinBalanceController,
        only: [:index],
        as: :coin_balance
      )

      resources(
        "/coin_balances/by_day",
        AddressCoinBalanceByDayController,
        only: [:index],
        as: :coin_balance_by_day
      )
    end

    resources "/tokens", Tokens.TokenController, only: [:show], as: :token do
      resources(
        "/token_transfers",
        Tokens.TransferController,
        only: [:index],
        as: :transfer
      )

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

      resources(
        "/inventory",
        Tokens.InventoryController,
        only: [:index],
        as: :inventory
      )
    end

    resources(
      "/smart_contracts",
      SmartContractController,
      only: [:index, :show],
      as: :smart_contract
    )

    get("/search", ChainController, :search)

    get("/chain_blocks", ChainController, :chain_blocks, as: :chain_blocks)

    get("/api_docs", APIDocsController, :index)
  end
end
