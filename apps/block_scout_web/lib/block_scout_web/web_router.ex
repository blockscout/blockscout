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

    resources("/market-history-chart", Chain.MarketHistoryChartController,
      only: [:show],
      singleton: true
    )

    resources("/transaction-history-chart", Chain.TransactionHistoryChartController,
      only: [:show],
      singleton: true
    )

    resources("/gas-usage-history-chart", Chain.GasUsageHistoryChartController,
      only: [:show],
      singleton: true
    )

    resources "/block", BlockController, only: [:show], param: "hash_or_number" do
      resources("/transactions", BlockTransactionController, only: [:index], as: :transaction)
    end

    resources("/blocks", BlockController, as: :blocks, only: [:index])

    resources "/blocks", BlockController, as: :block_secondary, only: [:show], param: "hash_or_number" do
      resources("/transactions", BlockTransactionController, only: [:index], as: :transaction)
    end

    get("/reorgs", BlockController, :reorg, as: :reorg)

    get("/uncles", BlockController, :uncle, as: :uncle)

    get("/validators", StakesController, :index, as: :validators, assigns: %{filter: :validator})
    get("/active-pools", StakesController, :index, as: :active_pools, assigns: %{filter: :active})
    get("/inactive-pools", StakesController, :index, as: :inactive_pools, assigns: %{filter: :inactive})

    resources("/pending-transactions", PendingTransactionController, only: [:index])

    resources("/recent-transactions", RecentTransactionsController, only: [:index])

    get("/txs", TransactionController, :index)

    resources "/tx", TransactionController, only: [:show] do
      resources(
        "/internal-transactions",
        TransactionInternalTransactionController,
        only: [:index],
        as: :internal_transaction
      )

      resources(
        "/raw-trace",
        TransactionRawTraceController,
        only: [:index],
        as: :raw_trace
      )

      resources("/logs", TransactionLogController, only: [:index], as: :log)

      resources("/token-transfers", TransactionTokenTransferController,
        only: [:index],
        as: :token_transfer
      )
    end

    resources("/accounts", AddressController, only: [:index])

    resources("/tokens", TokensController, only: [:index])

    resources("/bridged-tokens", BridgedTokensController, only: [:index, :show])

    resources "/address", AddressController, only: [:show] do
      resources("/transactions", AddressTransactionController, only: [:index], as: :transaction)

      resources(
        "/internal-transactions",
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
        "/decompiled-contracts",
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
        "/verify-via-flattened-code",
        AddressContractVerificationViaFlattenedCodeController,
        only: [:new],
        as: :verify_contract_via_flattened_code
      )

      resources(
        "/verify-via-json",
        AddressContractVerificationViaJsonController,
        only: [:new],
        as: :verify_contract_via_json
      )

      resources(
        "/verify-via-standard-json-input",
        AddressContractVerificationViaStandardJsonInputController,
        only: [:new],
        as: :verify_contract_via_standard_json_input
      )

      resources(
        "/verify-vyper-contract",
        AddressContractVerificationVyperController,
        only: [:new],
        as: :verify_vyper_contract
      )

      resources(
        "/read-contract",
        AddressReadContractController,
        only: [:index, :show],
        as: :read_contract
      )

      resources(
        "/read-proxy",
        AddressReadProxyController,
        only: [:index, :show],
        as: :read_proxy
      )

      resources(
        "/write-contract",
        AddressWriteContractController,
        only: [:index, :show],
        as: :write_contract
      )

      resources(
        "/write-proxy",
        AddressWriteProxyController,
        only: [:index, :show],
        as: :write_proxy
      )

      resources(
        "/token-transfers",
        AddressTokenTransferController,
        only: [:index],
        as: :token_transfers
      )

      resources("/tokens", AddressTokenController, only: [:index], as: :token) do
        resources(
          "/token-transfers",
          AddressTokenTransferController,
          only: [:index],
          as: :transfers
        )
      end

      resources(
        "/token-balances",
        AddressTokenBalanceController,
        only: [:index],
        as: :token_balance
      )

      resources(
        "/coin-balances",
        AddressCoinBalanceController,
        only: [:index],
        as: :coin_balance
      )

      resources(
        "/coin-balances/by-day",
        AddressCoinBalanceByDayController,
        only: [:index],
        as: :coin_balance_by_day
      )
    end

    resources "/token", Tokens.TokenController, only: [:show], as: :token do
      resources(
        "/token-transfers",
        Tokens.TransferController,
        only: [:index],
        as: :transfer
      )

      resources(
        "/read-contract",
        Tokens.ReadContractController,
        only: [:index],
        as: :read_contract
      )

      resources(
        "/token-holders",
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
          "/token-transfers",
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

        resources(
          "/token-holders",
          Tokens.Instance.HolderController,
          only: [:index],
          as: :holder
        )
      end
    end

    resources "/tokens", Tokens.TokenController, only: [:show], as: :token_secondary do
      resources(
        "/token-transfers",
        Tokens.TransferController,
        only: [:index],
        as: :transfer
      )

      resources(
        "/read-contract",
        Tokens.ReadContractController,
        only: [:index],
        as: :read_contract
      )

      resources(
        "/token-holders",
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
          "/token-transfers",
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

        resources(
          "/token-holders",
          Tokens.Instance.HolderController,
          only: [:index],
          as: :holder
        )
      end
    end

    resources(
      "/smart-contracts",
      SmartContractController,
      only: [:index, :show],
      as: :smart_contract
    )

    resources("/gas-tracker-consumers-3hrs", GasTrackerConsumersThreeHrsController,
      only: [:index],
      as: :gas_tracker_consumers_3hrs
    )

    resources("/gas-tracker-consumers-24hrs", GasTrackerConsumersDayController,
      only: [:index],
      as: :gas_tracker_consumers_day
    )

    resources("/gas-tracker-spenders-3hrs", GasTrackerSpendersThreeHrsController,
      only: [:index],
      as: :gas_tracker_spenders_3hrs
    )

    resources("/gas-tracker-spenders-24hrs", GasTrackerSpendersDayController,
      only: [:index],
      as: :gas_tracker_spenders_day
    )

    get("/address-counters", AddressController, :address_counters)

    get("/search", ChainController, :search)

    get("/search-logs", AddressLogsController, :search_logs)

    get("/search-results", SearchController, :search_results)

    get("/csv-export", CsvExportController, :index)

    post("/captcha", CaptchaController, :index)

    get("/transactions-csv", AddressTransactionController, :transactions_csv)

    get("/token-autocomplete", ChainController, :token_autocomplete)

    get("/token-transfers-csv", AddressTransactionController, :token_transfers_csv)

    get("/internal-transactions-csv", AddressTransactionController, :internal_transactions_csv)

    get("/logs-csv", AddressTransactionController, :logs_csv)

    get("/chain-blocks", ChainController, :chain_blocks, as: :chain_blocks)

    get("/token-counters", Tokens.TokenController, :token_counters)

    get("/faucet", FaucetController, :index)

    post("/faucet", FaucetController, :request)

    get("/*path", PageNotFoundController, :index)
  end
end
