import Config

import Bitwise

indexer_memory_limit =
  "INDEXER_MEMORY_LIMIT"
  |> System.get_env("1")
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> 1
  end

config :indexer,
  memory_limit: indexer_memory_limit <<< 30

indexer_empty_blocks_sanitizer_batch_size =
  if System.get_env("INDEXER_EMPTY_BLOCKS_SANITIZER_BATCH_SIZE") do
    case Integer.parse(System.get_env("INDEXER_EMPTY_BLOCKS_SANITIZER_BATCH_SIZE")) do
      {integer, ""} -> integer
      _ -> 100
    end
  else
    100
  end

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer, batch_size: indexer_empty_blocks_sanitizer_batch_size

config :block_scout_web, :footer,
  chat_link: System.get_env("FOOTER_CHAT_LINK", "https://discord.gg/XmNatGKbPS"),
  forum_link: System.get_env("FOOTER_FORUM_LINK", "https://forum.poa.network/c/blockscout"),
  github_link: System.get_env("FOOTER_GITHUB_LINK", "https://github.com/blockscout/blockscout")

if config_env() == :prod do
  ######################
  ### BlockScout Web ###
  ######################

  config :block_scout_web,
    version: System.get_env("BLOCKSCOUT_VERSION"),
    release_link: System.get_env("RELEASE_LINK"),
    decompiled_smart_contract_token: System.get_env("DECOMPILED_SMART_CONTRACT_TOKEN"),
    show_percentage: if(System.get_env("SHOW_ADDRESS_MARKETCAP_PERCENTAGE", "true") == "false", do: false, else: true),
    checksum_address_hashes: if(System.get_env("CHECKSUM_ADDRESS_HASHES", "true") == "false", do: false, else: true)

  config :block_scout_web, BlockScoutWeb.Chain,
    network: System.get_env("NETWORK"),
    subnetwork: System.get_env("SUBNETWORK"),
    network_icon: System.get_env("NETWORK_ICON"),
    logo: System.get_env("LOGO"),
    logo_footer: System.get_env("LOGO_FOOTER"),
    logo_text: System.get_env("LOGO_TEXT"),
    has_emission_funds: false,
    show_maintenance_alert: System.get_env("SHOW_MAINTENANCE_ALERT", "false") == "true",
    enable_testnet_label: System.get_env("SHOW_TESTNET_LABEL", "false") == "true",
    testnet_label_text: System.get_env("TESTNET_LABEL_TEXT", "Testnet")

  config :block_scout_web,
    link_to_other_explorers: System.get_env("LINK_TO_OTHER_EXPLORERS") == "true",
    other_explorers: System.get_env("OTHER_EXPLORERS"),
    other_networks: System.get_env("SUPPORTED_CHAINS"),
    webapp_url: System.get_env("WEBAPP_URL"),
    api_url: System.get_env("API_URL"),
    apps_menu: if(System.get_env("APPS_MENU", "false") == "true", do: true, else: false),
    external_apps: System.get_env("EXTERNAL_APPS"),
    gas_price: System.get_env("GAS_PRICE", nil),
    restricted_list: System.get_env("RESTRICTED_LIST", nil),
    restricted_list_key: System.get_env("RESTRICTED_LIST_KEY", nil),
    dark_forest_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST"),
    dark_forest_addresses_v_0_5: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST_V_0_5"),
    circles_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_CIRCLES"),
    test_tokens_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_TEST_TOKEN"),
    max_size_to_show_array_as_is: Integer.parse(System.get_env("MAX_SIZE_UNLESS_HIDE_ARRAY", "50")),
    max_length_to_show_string_without_trimming: System.get_env("MAX_STRING_LENGTH_WITHOUT_TRIMMING", "2040"),
    re_captcha_secret_key: System.get_env("RE_CAPTCHA_SECRET_KEY", nil),
    re_captcha_client_key: System.get_env("RE_CAPTCHA_CLIENT_KEY", nil),
    admin_panel_enabled: System.get_env("ADMIN_PANEL_ENABLED", "") == "true"

  default_api_rate_limit = 50
  default_api_rate_limit_str = Integer.to_string(default_api_rate_limit)

  global_api_rate_limit_value =
    "API_RATE_LIMIT"
    |> System.get_env(default_api_rate_limit_str)
    |> Integer.parse()
    |> case do
      {integer, ""} -> integer
      _ -> default_api_rate_limit
    end

  api_rate_limit_by_key_value =
    "API_RATE_LIMIT_BY_KEY"
    |> System.get_env(default_api_rate_limit_str)
    |> Integer.parse()
    |> case do
      {integer, ""} -> integer
      _ -> default_api_rate_limit
    end

  api_rate_limit_by_ip_value =
    "API_RATE_LIMIT_BY_IP"
    |> System.get_env(default_api_rate_limit_str)
    |> Integer.parse()
    |> case do
      {integer, ""} -> integer
      _ -> default_api_rate_limit
    end

  config :block_scout_web, :api_rate_limit,
    global_limit: global_api_rate_limit_value,
    limit_by_key: api_rate_limit_by_key_value,
    limit_by_ip: api_rate_limit_by_ip_value,
    static_api_key: System.get_env("API_RATE_LIMIT_STATIC_API_KEY", nil),
    whitelisted_ips: System.get_env("API_RATE_LIMIT_WHITELISTED_IPS", nil)

  # Configures History
  price_chart_config =
    if System.get_env("SHOW_PRICE_CHART", "false") != "false" do
      %{market: [:price, :market_cap]}
    else
      %{}
    end

  tx_chart_config =
    if System.get_env("SHOW_TXS_CHART", "true") == "true" do
      %{transactions: [:transactions_per_day]}
    else
      %{}
    end

  config :block_scout_web,
    chart_config: Map.merge(price_chart_config, tx_chart_config)

  config :block_scout_web, BlockScoutWeb.Chain.Address.CoinBalance,
    # days
    coin_balance_history_days: System.get_env("COIN_BALANCE_HISTORY_DAYS", "10")

  config :block_scout_web, BlockScoutWeb.ApiRouter,
    writing_enabled: System.get_env("DISABLE_WRITE_API") != "true",
    reading_enabled: System.get_env("DISABLE_READ_API") != "true",
    wobserver_enabled: System.get_env("WOBSERVER_ENABLED") == "true"

  config :block_scout_web, BlockScoutWeb.WebRouter, enabled: System.get_env("DISABLE_WEBAPP") != "true"

  config :block_scout_web, BlockScoutWeb.Endpoint,
    server: true,
    cache_static_manifest: "priv/static/cache_manifest.json",
    force_ssl: false,
    secret_key_base: System.get_env("SECRET_KEY_BASE"),
    check_origin: System.get_env("CHECK_ORIGIN", "false") == "true" || false,
    http: [port: System.get_env("PORT")],
    url: [
      scheme: System.get_env("BLOCKSCOUT_PROTOCOL") || "https",
      port: System.get_env("PORT"),
      host: System.get_env("BLOCKSCOUT_HOST") || "localhost",
      path: System.get_env("NETWORK_PATH") || "/",
      api_path: System.get_env("API_PATH") || "/"
    ]

  ########################
  ### Ethereum JSONRPC ###
  ########################

  config :ethereum_jsonrpc,
    rpc_transport: if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http", do: :http, else: :ipc),
    ipc_path: System.get_env("IPC_PATH")

  debug_trace_transaction_timeout = System.get_env("ETHEREUM_JSONRPC_DEBUG_TRACE_TRANSACTION_TIMEOUT", "5s")
  config :ethereum_jsonrpc, EthereumJSONRPC.Geth, debug_trace_transaction_timeout: debug_trace_transaction_timeout

  ################
  ### Explorer ###
  ################

  disable_indexer = System.get_env("DISABLE_INDEXER")
  disable_webapp = System.get_env("DISABLE_WEBAPP")

  config :explorer,
    coin: System.get_env("COIN") || "POA",
    allowed_evm_versions:
      System.get_env("ALLOWED_EVM_VERSIONS") ||
        "homestead,tangerineWhistle,spuriousDragon,byzantium,constantinople,petersburg,istanbul,berlin,london,default",
    include_uncles_in_average_block_time:
      if(System.get_env("UNCLES_IN_AVERAGE_BLOCK_TIME") == "true", do: true, else: false),
    healthy_blocks_period: System.get_env("HEALTHY_BLOCKS_PERIOD") || :timer.minutes(5),
    realtime_events_sender:
      if(disable_webapp != "true",
        do: Explorer.Chain.Events.SimpleSender,
        else: Explorer.Chain.Events.DBSender
      )

  config :explorer, Explorer.Chain.Events.Listener,
    enabled:
      if(disable_webapp == "true" && disable_indexer == "true",
        do: false,
        else: true
      )

  config :explorer, Explorer.ChainSpec.GenesisData,
    chain_spec_path: System.get_env("CHAIN_SPEC_PATH"),
    emission_format: System.get_env("EMISSION_FORMAT", "DEFAULT"),
    rewards_contract_address: System.get_env("REWARDS_CONTRACT", "0xeca443e8e1ab29971a45a9c57a6a9875701698a5")

  config :explorer, Explorer.Chain.Cache.BlockNumber,
    ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
    global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

  address_sum_global_ttl =
    "CACHE_ADDRESS_SUM_PERIOD"
    |> System.get_env("")
    |> Integer.parse()
    |> case do
      {integer, ""} -> :timer.seconds(integer)
      _ -> :timer.minutes(60)
    end

  config :explorer, Explorer.Chain.Cache.AddressSum, global_ttl: address_sum_global_ttl

  config :explorer, Explorer.Chain.Cache.AddressSumMinusBurnt, global_ttl: address_sum_global_ttl

  cache_address_with_balances_update_interval = System.get_env("CACHE_ADDRESS_WITH_BALANCES_UPDATE_INTERVAL")

  balances_update_interval =
    if cache_address_with_balances_update_interval do
      case Integer.parse(cache_address_with_balances_update_interval) do
        {integer, ""} -> integer
        _ -> nil
      end
    end

  config :explorer, Explorer.Counters.AddressesWithBalanceCounter,
    update_interval_in_seconds: balances_update_interval || 30 * 60

  config :explorer, Explorer.Counters.AddressesCounter, update_interval_in_seconds: balances_update_interval || 30 * 60

  config :explorer, Explorer.Chain.Cache.GasUsage,
    enabled: System.get_env("CACHE_ENABLE_TOTAL_GAS_USAGE_COUNTER") == "true"

  config :explorer, Explorer.ExchangeRates,
    enabled: System.get_env("DISABLE_EXCHANGE_RATES") != "true",
    coingecko_coin_id: System.get_env("EXCHANGE_RATES_COINGECKO_COIN_ID"),
    coingecko_api_key: System.get_env("EXCHANGE_RATES_COINGECKO_API_KEY"),
    coinmarketcap_api_key: System.get_env("EXCHANGE_RATES_COINMARKETCAP_API_KEY"),
    fetch_btc_value: System.get_env("EXCHANGE_RATES_FETCH_BTC_VALUE") == "true"

  exchange_rates_source =
    cond do
      System.get_env("EXCHANGE_RATES_SOURCE") == "coin_gecko" -> Explorer.ExchangeRates.Source.CoinGecko
      System.get_env("EXCHANGE_RATES_SOURCE") == "coin_market_cap" -> Explorer.ExchangeRates.Source.CoinMarketCap
      true -> Explorer.ExchangeRates.Source.CoinGecko
    end

  config :explorer, Explorer.ExchangeRates.Source, source: exchange_rates_source

  config :explorer, Explorer.KnownTokens, enabled: System.get_env("DISABLE_KNOWN_TOKENS") != "true", store: :ets

  config :explorer, Explorer.Market.History.Cataloger, enabled: disable_indexer != "true"

  config :explorer, Explorer.Chain.Cache.MinMissingBlockNumber, enabled: System.get_env("DISABLE_WRITE_API") != "true"

  txs_stats_init_lag =
    System.get_env("TXS_HISTORIAN_INIT_LAG", "0")
    |> Integer.parse()
    |> elem(0)
    |> :timer.minutes()

  txs_stats_days_to_compile_at_init =
    System.get_env("TXS_STATS_DAYS_TO_COMPILE_AT_INIT", "40")
    |> Integer.parse()
    |> elem(0)

  config :explorer, Explorer.Chain.Transaction.History.Historian,
    enabled: System.get_env("ENABLE_TXS_STATS", "true") != "false",
    init_lag: txs_stats_init_lag,
    days_to_compile_at_init: txs_stats_days_to_compile_at_init

  history_fetch_interval =
    case Integer.parse(System.get_env("HISTORY_FETCH_INTERVAL", "")) do
      {mins, ""} -> mins
      _ -> 60
    end
    |> :timer.minutes()

  config :explorer, Explorer.History.Process, history_fetch_interval: history_fetch_interval

  if System.get_env("METADATA_CONTRACT") && System.get_env("VALIDATORS_CONTRACT") do
    config :explorer, Explorer.Validator.MetadataRetriever,
      metadata_contract_address: System.get_env("METADATA_CONTRACT"),
      validators_contract_address: System.get_env("VALIDATORS_CONTRACT")

    config :explorer, Explorer.Validator.MetadataProcessor, enabled: disable_indexer != "true"
  else
    config :explorer, Explorer.Validator.MetadataProcessor, enabled: false
  end

  config :explorer, Explorer.Chain.Block.Reward,
    validators_contract_address: System.get_env("VALIDATORS_CONTRACT"),
    keys_manager_contract_address: System.get_env("KEYS_MANAGER_CONTRACT")

  case System.get_env("SUPPLY_MODULE") do
    "rsk" ->
      config :explorer, supply: Explorer.Chain.Supply.RSK

    _ ->
      :ok
  end

  config :explorer,
    solc_bin_api_url: "https://solc-bin.ethereum.org",
    checksum_function: System.get_env("CHECKSUM_FUNCTION") && String.to_atom(System.get_env("CHECKSUM_FUNCTION"))

  config :explorer, Explorer.Chain.Cache.Blocks,
    ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
    global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

  config :explorer, Explorer.Chain.Cache.Transactions,
    ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
    global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

  config :explorer, Explorer.Chain.Cache.Accounts,
    ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
    global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

  config :explorer, Explorer.Chain.Cache.Uncles,
    ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
    global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

  config :explorer, Explorer.ThirdPartyIntegrations.Sourcify,
    server_url: System.get_env("SOURCIFY_SERVER_URL") || "https://sourcify.dev/server",
    enabled: System.get_env("ENABLE_SOURCIFY_INTEGRATION") == "true",
    chain_id: System.get_env("CHAIN_ID"),
    repo_url: System.get_env("SOURCIFY_REPO_URL") || "https://repo.sourcify.dev/contracts"

  pool_size =
    if System.get_env("DATABASE_READ_ONLY_API_URL"),
      do: String.to_integer(System.get_env("POOL_SIZE", "50")),
      else: String.to_integer(System.get_env("POOL_SIZE", "40"))

  config :explorer, Explorer.Repo,
    url: System.get_env("DATABASE_URL"),
    pool_size: pool_size,
    ssl: String.equivalent?(System.get_env("ECTO_USE_SSL") || "true", "true")

  database_api_url =
    if System.get_env("DATABASE_READ_ONLY_API_URL"),
      do: System.get_env("DATABASE_READ_ONLY_API_URL"),
      else: System.get_env("DATABASE_URL")

  pool_size_api =
    if System.get_env("DATABASE_READ_ONLY_API_URL"),
      do: String.to_integer(System.get_env("POOL_SIZE_API", "50")),
      else: String.to_integer(System.get_env("POOL_SIZE_API", "10"))

  # Configures API the database
  config :explorer, Explorer.Repo.Replica1,
    url: database_api_url,
    pool_size: pool_size_api,
    ssl: String.equivalent?(System.get_env("ECTO_USE_SSL") || "true", "true")

  variant =
    if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
      "parity"
    else
      System.get_env("ETHEREUM_JSONRPC_VARIANT")
      |> String.split(".")
      |> List.last()
      |> String.downcase()
    end

  variant_name_map = %{
    "arbitrum" => EthereumJSONRPC.Arbitrum,
    "besu" => EthereumJSONRPC.Besu,
    "ganache" => EthereumJSONRPC.Ganache,
    "geth" => EthereumJSONRPC.Geth,
    "parity" => EthereumJSONRPC.Parity,
    "rsk" => EthereumJSONRPC.RSK,
    "erigon" => EthereumJSONRPC.Erigon
  }

  cond do
    variant in ["arbitrum", "ganache", "geth"] ->
      config :explorer,
        json_rpc_named_arguments: [
          transport: EthereumJSONRPC.HTTP,
          transport_options: [
            http: EthereumJSONRPC.HTTP.HTTPoison,
            url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL"),
            http_options: [
              recv_timeout: :timer.minutes(1),
              timeout: :timer.minutes(1),
              hackney: [pool: :ethereum_jsonrpc]
            ]
          ],
          variant: variant_name_map[variant]
        ],
        subscribe_named_arguments: [
          transport: EthereumJSONRPC.WebSocket,
          transport_options: [
            web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
            url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
          ],
          variant: variant_name_map[variant]
        ]

    variant in ["besu", "parity", "rsk", "erigon"] ->
      config :explorer,
        json_rpc_named_arguments: [
          transport: EthereumJSONRPC.HTTP,
          transport_options: [
            http: EthereumJSONRPC.HTTP.HTTPoison,
            url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL"),
            method_to_url: [
              eth_call: System.get_env("ETHEREUM_JSONRPC_TRACE_URL"),
              eth_getBalance: System.get_env("ETHEREUM_JSONRPC_TRACE_URL"),
              trace_replayTransaction: System.get_env("ETHEREUM_JSONRPC_TRACE_URL")
            ],
            http_options: [
              recv_timeout: :timer.minutes(1),
              timeout: :timer.minutes(1),
              hackney: [pool: :ethereum_jsonrpc]
            ]
          ],
          variant: variant_name_map[variant]
        ],
        subscribe_named_arguments: [
          transport: EthereumJSONRPC.WebSocket,
          transport_options: [
            web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
            url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
          ],
          variant: variant_name_map[variant]
        ]
  end

  ###############
  ### Indexer ###
  ###############

  block_transformers = %{
    "clique" => Indexer.Transform.Blocks.Clique,
    "base" => Indexer.Transform.Blocks.Base
  }

  # Compile time environment variable access requires recompilation.
  configured_transformer = System.get_env("BLOCK_TRANSFORMER") || "base"

  block_transformer =
    case Map.get(block_transformers, configured_transformer) do
      nil ->
        raise """
        No such block transformer: #{configured_transformer}.

        Valid values are:
        #{Enum.join(Map.keys(block_transformers), "\n")}

        Please update environment variable BLOCK_TRANSFORMER accordingly.
        """

      transformer ->
        transformer
    end

  config :indexer,
    block_transformer: block_transformer,
    metadata_updater_seconds_interval:
      String.to_integer(System.get_env("TOKEN_METADATA_UPDATE_INTERVAL") || "#{2 * 24 * 60 * 60}"),
    first_block: System.get_env("FIRST_BLOCK") || "",
    last_block: System.get_env("LAST_BLOCK") || "",
    trace_first_block: System.get_env("TRACE_FIRST_BLOCK") || "",
    trace_last_block: System.get_env("TRACE_LAST_BLOCK") || "",
    fetch_rewards_way: System.get_env("FETCH_REWARDS_WAY", "trace_block")

  config :indexer, Indexer.Fetcher.PendingTransaction.Supervisor,
    disabled?:
      System.get_env("ETHEREUM_JSONRPC_VARIANT") == "besu" ||
        System.get_env("INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER", "false") == "true"

  token_balance_on_demand_fetcher_threshold_minutes =
    System.get_env("TOKEN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD_MINUTES")

  token_balance_on_demand_fetcher_threshold =
    case token_balance_on_demand_fetcher_threshold_minutes &&
           Integer.parse(token_balance_on_demand_fetcher_threshold_minutes) do
      {integer, ""} -> integer
      _ -> 60
    end

  config :indexer, Indexer.Fetcher.TokenBalanceOnDemand, threshold: token_balance_on_demand_fetcher_threshold

  coin_balance_on_demand_fetcher_threshold_minutes = System.get_env("COIN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD_MINUTES")

  coin_balance_on_demand_fetcher_threshold =
    case coin_balance_on_demand_fetcher_threshold_minutes &&
           Integer.parse(coin_balance_on_demand_fetcher_threshold_minutes) do
      {integer, ""} -> integer
      _ -> 60
    end

  config :indexer, Indexer.Fetcher.CoinBalanceOnDemand, threshold: coin_balance_on_demand_fetcher_threshold

  # config :indexer, Indexer.Fetcher.ReplacedTransaction.Supervisor, disabled?: true
  config :indexer, Indexer.Fetcher.BlockReward.Supervisor,
    disabled?: System.get_env("INDEXER_DISABLE_BLOCK_REWARD_FETCHER", "false") == "true"

  config :indexer, Indexer.Fetcher.InternalTransaction.Supervisor,
    disabled?: System.get_env("INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER", "false") == "true"

  config :indexer, Indexer.Fetcher.CoinBalance.Supervisor,
    disabled?: System.get_env("INDEXER_DISABLE_ADDRESS_COIN_BALANCE_FETCHER", "false") == "true"

  config :indexer, Indexer.Fetcher.TokenUpdater.Supervisor,
    disabled?: System.get_env("INDEXER_DISABLE_CATALOGED_TOKEN_UPDATER_FETCHER", "false") == "true"

  config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer.Supervisor,
    disabled?: System.get_env("INDEXER_DISABLE_EMPTY_BLOCK_SANITIZER", "false") == "true"

  config :indexer, Indexer.Supervisor, enabled: System.get_env("DISABLE_INDEXER") != "true"

  variant =
    if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
      "parity"
    else
      System.get_env("ETHEREUM_JSONRPC_VARIANT")
      |> String.split(".")
      |> List.last()
      |> String.downcase()
    end

  case variant do
    "arbitrum" ->
      config :indexer,
        block_interval: :timer.seconds(5),
        json_rpc_named_arguments: [
          transport:
            if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http",
              do: EthereumJSONRPC.HTTP,
              else: EthereumJSONRPC.IPC
            ),
          transport_options: [
            http: EthereumJSONRPC.HTTP.HTTPoison,
            url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL") || "http://localhost:8545",
            http_options: [
              recv_timeout: :timer.minutes(5),
              timeout: :timer.minutes(5),
              hackney: [pool: :ethereum_jsonrpc]
            ]
          ],
          variant: EthereumJSONRPC.Arbitrum
        ],
        subscribe_named_arguments: [
          transport:
            System.get_env("ETHEREUM_JSONRPC_WS_URL") && System.get_env("ETHEREUM_JSONRPC_WS_URL") !== "" &&
              EthereumJSONRPC.WebSocket,
          transport_options: [
            web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
            url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
          ]
        ]

    "besu" ->
      config :indexer,
        block_interval: :timer.seconds(5),
        json_rpc_named_arguments: [
          transport:
            if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http",
              do: EthereumJSONRPC.HTTP,
              else: EthereumJSONRPC.IPC
            ),
          transport_options: [
            http: EthereumJSONRPC.HTTP.HTTPoison,
            url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL"),
            method_to_url: [
              eth_getBalance: System.get_env("ETHEREUM_JSONRPC_TRACE_URL"),
              trace_block: System.get_env("ETHEREUM_JSONRPC_TRACE_URL"),
              trace_replayTransaction: System.get_env("ETHEREUM_JSONRPC_TRACE_URL")
            ],
            http_options: [
              recv_timeout: :timer.minutes(10),
              timeout: :timer.minutes(10),
              hackney: [pool: :ethereum_jsonrpc]
            ]
          ],
          variant: EthereumJSONRPC.Besu
        ],
        subscribe_named_arguments: [
          transport:
            System.get_env("ETHEREUM_JSONRPC_WS_URL") && System.get_env("ETHEREUM_JSONRPC_WS_URL") !== "" &&
              EthereumJSONRPC.WebSocket,
          transport_options: [
            web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
            url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
          ]
        ]

    "ganache" ->
      config :indexer,
        block_interval: :timer.seconds(5),
        json_rpc_named_arguments: [
          transport:
            if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http",
              do: EthereumJSONRPC.HTTP,
              else: EthereumJSONRPC.IPC
            ),
          transport_options: [
            http: EthereumJSONRPC.HTTP.HTTPoison,
            url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL") || "http://localhost:7545",
            http_options: [
              recv_timeout: :timer.minutes(1),
              timeout: :timer.minutes(1),
              hackney: [pool: :ethereum_jsonrpc]
            ]
          ],
          variant: EthereumJSONRPC.Ganache
        ],
        subscribe_named_arguments: [
          transport:
            System.get_env("ETHEREUM_JSONRPC_WS_URL") && System.get_env("ETHEREUM_JSONRPC_WS_URL") !== "" &&
              EthereumJSONRPC.WebSocket,
          transport_options: [
            web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
            url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
          ]
        ]

    "geth" ->
      config :indexer,
        block_interval: :timer.seconds(5),
        json_rpc_named_arguments: [
          transport:
            if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http",
              do: EthereumJSONRPC.HTTP,
              else: EthereumJSONRPC.IPC
            ),
          transport_options: [
            http: EthereumJSONRPC.HTTP.HTTPoison,
            url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL"),
            http_options: [
              recv_timeout: :timer.minutes(10),
              timeout: :timer.minutes(10),
              hackney: [pool: :ethereum_jsonrpc]
            ]
          ],
          variant: EthereumJSONRPC.Geth
        ],
        subscribe_named_arguments: [
          transport:
            System.get_env("ETHEREUM_JSONRPC_WS_URL") && System.get_env("ETHEREUM_JSONRPC_WS_URL") !== "" &&
              EthereumJSONRPC.WebSocket,
          transport_options: [
            web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
            url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
          ]
        ]

    "parity" ->
      config :indexer,
        block_interval: :timer.seconds(5),
        json_rpc_named_arguments: [
          transport:
            if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http",
              do: EthereumJSONRPC.HTTP,
              else: EthereumJSONRPC.IPC
            ),
          transport_options: [
            http: EthereumJSONRPC.HTTP.HTTPoison,
            url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL"),
            method_to_url: [
              eth_getBalance: System.get_env("ETHEREUM_JSONRPC_TRACE_URL"),
              trace_block: System.get_env("ETHEREUM_JSONRPC_TRACE_URL"),
              trace_replayTransaction: System.get_env("ETHEREUM_JSONRPC_TRACE_URL")
            ],
            http_options: [
              recv_timeout: :timer.minutes(10),
              timeout: :timer.minutes(10),
              hackney: [pool: :ethereum_jsonrpc]
            ]
          ],
          variant: EthereumJSONRPC.Parity
        ],
        subscribe_named_arguments: [
          transport:
            System.get_env("ETHEREUM_JSONRPC_WS_URL") && System.get_env("ETHEREUM_JSONRPC_WS_URL") !== "" &&
              EthereumJSONRPC.WebSocket,
          transport_options: [
            web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
            url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
          ]
        ]

    "rsk" ->
      config :indexer,
        block_interval: :timer.seconds(5),
        blocks_concurrency: 1,
        receipts_concurrency: 1,
        json_rpc_named_arguments: [
          transport:
            if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http",
              do: EthereumJSONRPC.HTTP,
              else: EthereumJSONRPC.IPC
            ),
          transport_options: [
            http: EthereumJSONRPC.HTTP.HTTPoison,
            url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL"),
            method_to_url: [
              eth_getBalance: System.get_env("ETHEREUM_JSONRPC_TRACE_URL"),
              trace_block: System.get_env("ETHEREUM_JSONRPC_TRACE_URL"),
              trace_replayTransaction: System.get_env("ETHEREUM_JSONRPC_TRACE_URL")
            ],
            http_options: [
              recv_timeout: :timer.minutes(10),
              timeout: :timer.minutes(10),
              hackney: [pool: :ethereum_jsonrpc]
            ]
          ],
          variant: EthereumJSONRPC.RSK
        ],
        subscribe_named_arguments: [
          transport:
            System.get_env("ETHEREUM_JSONRPC_WS_URL") && System.get_env("ETHEREUM_JSONRPC_WS_URL") !== "" &&
              EthereumJSONRPC.WebSocket,
          transport_options: [
            web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
            url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
          ]
        ]

    "erigon" ->
      config :indexer,
        block_interval: :timer.seconds(5),
        json_rpc_named_arguments: [
          transport:
            if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http",
              do: EthereumJSONRPC.HTTP,
              else: EthereumJSONRPC.IPC
            ),
          transport_options: [
            http: EthereumJSONRPC.HTTP.HTTPoison,
            url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL"),
            method_to_url: [
              eth_getBalance: System.get_env("ETHEREUM_JSONRPC_TRACE_URL"),
              trace_block: System.get_env("ETHEREUM_JSONRPC_TRACE_URL"),
              trace_replayTransaction: System.get_env("ETHEREUM_JSONRPC_TRACE_URL")
            ],
            http_options: [
              recv_timeout: :timer.minutes(10),
              timeout: :timer.minutes(10),
              hackney: [pool: :ethereum_jsonrpc]
            ]
          ],
          variant: EthereumJSONRPC.Erigon
        ],
        subscribe_named_arguments: [
          transport:
            System.get_env("ETHEREUM_JSONRPC_WS_URL") && System.get_env("ETHEREUM_JSONRPC_WS_URL") !== "" &&
              EthereumJSONRPC.WebSocket,
          transport_options: [
            web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
            url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
          ]
        ]
  end
end
