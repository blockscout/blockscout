defmodule BlockScoutWeb.WebRouter do
  @moduledoc """
  Router for web app
  """
  use BlockScoutWeb, :router
  require Ueberauth

  alias BlockScoutWeb.Plug.CheckAccountWeb

  pipeline :browser do
    plug(BlockScoutWeb.Plug.Logger, application: :block_scout_web)
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader)
    plug(BlockScoutWeb.ChecksumAddress)
  end

  pipeline :account do
    plug(BlockScoutWeb.Plug.Logger, application: :block_scout_web)
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(CheckAccountWeb)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader)
    plug(BlockScoutWeb.ChecksumAddress)
  end

  if Mix.env() == :dev do
    forward("/sent_emails", Bamboo.SentEmailViewerPlug)
  end

  scope "/auth", BlockScoutWeb do
    pipe_through(:account)

    get("/profile", Account.AuthController, :profile)
    get("/logout", Account.AuthController, :logout)
    get("/:provider", Account.AuthController, :request)
    get("/:provider/callback", Account.AuthController, :callback)
  end

  scope "/account", BlockScoutWeb do
    pipe_through(:account)

    resources("/tag_address", Account.TagAddressController,
      only: [:index, :new, :create, :delete],
      as: :tag_address
    )

    resources("/tag_transaction", Account.TagTransactionController,
      only: [:index, :new, :create, :delete],
      as: :tag_transaction
    )

    resources("/watchlist", Account.WatchlistController,
      only: [:show],
      singleton: true,
      as: :watchlist
    )

    resources("/watchlist_address", Account.WatchlistAddressController,
      only: [:new, :create, :edit, :update, :delete],
      as: :watchlist_address
    )

    resources("/api_key", Account.ApiKeyController,
      only: [:new, :create, :edit, :update, :delete, :index],
      as: :api_key
    )

    resources("/custom_abi", Account.CustomABIController,
      only: [:new, :create, :edit, :update, :delete, :index],
      as: :custom_abi
    )

    resources("/public_tags_request", Account.PublicTagsRequestController,
      only: [:new, :create, :edit, :update, :delete, :index],
      as: :public_tags_request
    )
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

    resources "/block", BlockController, only: [:show], param: "hash_or_number" do
      resources("/transactions", BlockTransactionController, only: [:index], as: :transaction)
      resources("/withdrawals", BlockWithdrawalController, only: [:index], as: :withdrawal)
    end

    resources("/blocks", BlockController, as: :blocks, only: [:index])

    resources "/blocks", BlockController,
      as: :block_secondary,
      only: [:show],
      param: "hash_or_number" do
      resources("/transactions", BlockTransactionController, only: [:index], as: :transaction)
      resources("/withdrawals", BlockWithdrawalController, only: [:index], as: :withdrawal)
    end

    get("/reorgs", BlockController, :reorg, as: :reorg)

    get("/uncles", BlockController, :uncle, as: :uncle)

    resources("/pending-transactions", PendingTransactionController, only: [:index])

    resources("/recent-transactions", RecentTransactionsController, only: [:index])

    resources("/verified-contracts", VerifiedContractsController, only: [:index])

    resources("/withdrawals", WithdrawalController, only: [:index])

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

      resources("/state", TransactionStateController,
        only: [:index],
        as: :state
      )
    end

    resources("/accounts", AddressController, only: [:index])

    resources("/tokens", TokensController, only: [:index])

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
        "/verify-via-metadata-json",
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
        "/verify-via-multi-part-files",
        AddressContractVerificationViaMultiPartFilesController,
        only: [:new],
        as: :verify_contract_via_multi_part_files
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

      resources(
        "/withdrawals",
        AddressWithdrawalController,
        only: [:index],
        as: :withdrawal
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
        Tokens.ContractController,
        only: [:index],
        as: :read_contract
      )

      resources(
        "/write-contract",
        Tokens.ContractController,
        only: [:index],
        as: :write_contract
      )

      resources(
        "/read-proxy",
        Tokens.ContractController,
        only: [:index],
        as: :read_proxy
      )

      resources(
        "/write-proxy",
        Tokens.ContractController,
        only: [:index],
        as: :write_proxy
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
        Tokens.ContractController,
        only: [:index],
        as: :read_contract
      )

      resources(
        "/write-contract",
        Tokens.ContractController,
        only: [:index],
        as: :write_contract
      )

      resources(
        "/read-proxy",
        Tokens.ContractController,
        only: [:index],
        as: :read_proxy
      )

      resources(
        "/write-proxy",
        Tokens.ContractController,
        only: [:index],
        as: :write_proxy
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

    get("/address-counters", AddressController, :address_counters)

    get("/search", ChainController, :search)

    get("/search-logs", AddressLogsController, :search_logs)

    get("/search-results", SearchController, :search_results)

    get("/search-verified-contracts", VerifiedContractsController, :search_verified_contracts)

    get("/csv-export", CsvExportController, :index)

    get("/token-autocomplete", ChainController, :token_autocomplete)

    get("/chain-blocks", ChainController, :chain_blocks, as: :chain_blocks)

    get("/token-counters", Tokens.TokenController, :token_counters)

    get("/visualize/sol2uml", VisualizeSol2umlController, :index)

    get("/*path", PageNotFoundController, :index)
  end
end
