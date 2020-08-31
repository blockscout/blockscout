defmodule BlockScoutWeb.WebRouter do
  @moduledoc """
  Router for web app
  """
  use BlockScoutWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader)
    plug(BlockScoutWeb.ChecksumAddress)
  end

  # Disallows Iframes (write routes)
  scope "/", BlockScoutWeb do
    pipe_through(:browser)
  end

  # Allows Iframes (read-only routes)
  scope "/", BlockScoutWeb do
    pipe_through([:browser, BlockScoutWeb.Plug.AllowIframe])

    resources("/", ChainController, only: [:show], singleton: true, as: :chain)

    resources("/market_history_chart", Chain.MarketHistoryChartController,
      only: [:show],
      singleton: true
    )

    resources("/transaction_history_chart", Chain.TransactionHistoryChartController,
      only: [:show],
      singleton: true
    )

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

      resources(
        "/raw_trace",
        TransactionRawTraceController,
        only: [:index],
        as: :raw_trace
      )

      resources("/logs", TransactionLogController, only: [:index], as: :log)

      resources("/token_transfers", TransactionTokenTransferController,
        only: [:index],
        as: :token_transfer
      )
    end

    resources("/accounts", AddressController, only: [:index])

    resources("/tokens", TokensController, only: [:index])

    resources("/bridged-tokens", BridgedTokensController, only: [:index])

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
        "/decompiled_contracts",
        AddressDecompiledContractController,
        only: [:index],
        as: :decompiled_contract
      )

      resources(
        "/logs",
        AddressLogsController,
        only: [:index],
        as: :logs
      )

      resources(
        "/contract_verifications",
        AddressContractVerificationController,
        only: [:new],
        as: :verify_contract
      )

      resources(
        "/read_contract",
        AddressReadContractController,
        only: [:index, :show],
        as: :read_contract
      )

      resources(
        "/read_proxy",
        AddressReadProxyController,
        only: [:index, :show],
        as: :read_proxy
      )

      resources(
        "/write_contract",
        AddressWriteContractController,
        only: [:index, :show],
        as: :write_contract
      )

      resources(
        "/write_proxy",
        AddressWriteProxyController,
        only: [:index, :show],
        as: :write_proxy
      )

      resources(
        "/token_transfers",
        AddressTokenTransferController,
        only: [:index],
        as: :token_transfers
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

      resources(
        "/instance",
        Tokens.InstanceController,
        only: [:show],
        as: :instance
      ) do
        resources(
          "/token_transfers",
          Tokens.Instance.TransferController,
          only: [:index],
          as: :transfer
        )

        resources(
          "/metadata",
          Tokens.Instance.MetadataController,
          only: [:index],
          as: :metadata
        )
      end
    end

    resources(
      "/smart_contracts",
      SmartContractController,
      only: [:index, :show],
      as: :smart_contract
    )

    get("/address_counters", AddressController, :address_counters)

    get("/search", ChainController, :search)

    get("/search_logs", AddressLogsController, :search_logs)

    get("/transactions_csv", AddressTransactionController, :transactions_csv)

    get("/token_autocomplete", ChainController, :token_autocomplete)

    get("/token_transfers_csv", AddressTransactionController, :token_transfers_csv)

    get("/chain_blocks", ChainController, :chain_blocks, as: :chain_blocks)

    get("/token_counters", Tokens.TokenController, :token_counters)

    get("/*path", PageNotFoundController, :index)
  end
end
