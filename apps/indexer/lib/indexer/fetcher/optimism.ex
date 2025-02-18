defmodule Indexer.Fetcher.Optimism do
  @moduledoc """
  Contains common functions for Optimism* fetchers.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC,
    only: [
      json_rpc: 2,
      integer_to_quantity: 1,
      quantity_to_integer: 1,
      request: 1
    ]

  alias EthereumJSONRPC.Contract
  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Repo
  alias Indexer.Fetcher.RollupL1ReorgMonitor
  alias Indexer.Helper

  @fetcher_name :optimism
  @block_check_interval_range_size 100
  @finite_retries_number 3

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    Logger.metadata(fetcher: @fetcher_name)
    :ignore
  end

  @doc """
  Fetches the chain id from the RPC (or cache).

  ## Returns
  - The chain id as unsigned integer.
  - `nil` if the request failed.
  """
  @spec fetch_chain_id() :: non_neg_integer() | nil
  def fetch_chain_id do
    case ChainId.get_id() do
      nil ->
        Logger.error("Cannot read `eth_chainId`. Retrying...")
        :timer.sleep(3000)
        fetch_chain_id()

      chain_id ->
        chain_id
    end
  end

  @doc """
  Calculates average block time in milliseconds (based on the latest 100 blocks) divided by 2.
  Sends corresponding requests to the RPC node.
  Returns a tuple {:ok, block_check_interval, last_safe_block}
  where `last_safe_block` is the number of the recent `safe` or `latest` block (depending on which one is available).
  Returns {:error, description} in case of error.
  """
  @spec get_block_check_interval(list()) :: {:ok, non_neg_integer(), non_neg_integer()} | {:error, any()}
  def get_block_check_interval(json_rpc_named_arguments) do
    {last_safe_block, _} = Helper.get_safe_block(json_rpc_named_arguments)

    first_block = max(last_safe_block - @block_check_interval_range_size, 1)

    with {:ok, first_block_timestamp} <-
           Helper.get_block_timestamp_by_number_or_tag(
             first_block,
             json_rpc_named_arguments,
             Helper.infinite_retries_number()
           ),
         {:ok, last_safe_block_timestamp} <-
           Helper.get_block_timestamp_by_number_or_tag(
             last_safe_block,
             json_rpc_named_arguments,
             Helper.infinite_retries_number()
           ) do
      block_check_interval =
        ceil((last_safe_block_timestamp - first_block_timestamp) / (last_safe_block - first_block) * 1000 / 2)

      Logger.info("Block check interval is calculated as #{block_check_interval} ms.")
      {:ok, block_check_interval, last_safe_block}
    else
      {:error, error} ->
        {:error, "Failed to calculate block check interval due to #{inspect(error)}"}
    end
  end

  @doc """
  Fetches logs emitted by the specified contract (address)
  within the specified block range and the first topic from the RPC node.
  Performs a specified number of retries (up to) if the first attempt returns error.
  """
  @spec get_logs(
          non_neg_integer() | binary(),
          non_neg_integer() | binary(),
          binary(),
          binary() | list(),
          list(),
          non_neg_integer()
        ) :: {:ok, list()} | {:error, term()}
  def get_logs(from_block, to_block, address, topic0, json_rpc_named_arguments, retries) do
    # TODO: use the function from the Indexer.Helper module
    processed_from_block = if is_integer(from_block), do: integer_to_quantity(from_block), else: from_block
    processed_to_block = if is_integer(to_block), do: integer_to_quantity(to_block), else: to_block

    req =
      request(%{
        id: 0,
        method: "eth_getLogs",
        params: [
          %{
            :fromBlock => processed_from_block,
            :toBlock => processed_to_block,
            :address => address,
            :topics => [topic0]
          }
        ]
      })

    error_message = &"Cannot fetch logs for the block range #{from_block}..#{to_block}. Error: #{inspect(&1)}"

    Helper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  @doc """
  Fetches transaction data by its hash using RPC request.
  Performs a specified number of retries (up to) if the first attempt returns error.
  """
  @spec get_transaction_by_hash(binary() | nil, list(), non_neg_integer()) :: {:ok, any()} | {:error, any()}
  def get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left \\ @finite_retries_number)

  def get_transaction_by_hash(hash, _json_rpc_named_arguments, _retries_left) when is_nil(hash), do: {:ok, nil}

  def get_transaction_by_hash(hash, json_rpc_named_arguments, retries) do
    req =
      request(%{
        id: 0,
        method: "eth_getTransactionByHash",
        params: [hash]
      })

    error_message = &"eth_getTransactionByHash failed. Error: #{inspect(&1)}"

    Helper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  @doc """
  Forms JSON RPC named arguments for the given RPC URL.
  """
  @spec json_rpc_named_arguments(binary()) :: list()
  def json_rpc_named_arguments(optimism_l1_rpc) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        urls: [optimism_l1_rpc],
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end

  @doc """
    Does initializations for `Indexer.Fetcher.Optimism.WithdrawalEvent`, `Indexer.Fetcher.Optimism.OutputRoot`, or
    `Indexer.Fetcher.Optimism.Deposit` module. Contains common code used by these modules.

    ## Parameters
    - `output_oracle`: An address of L2OutputOracle contract on L1.
                       Must be `nil` if the `caller` is not `Indexer.Fetcher.Optimism.OutputRoot` module.
    - `caller`: The module that called this function.

    ## Returns
    - A resulting map for the `handle_continue` handler of the calling module.
  """
  @spec init_continue(binary() | nil, module()) :: {:noreply, map()} | {:stop, :normal, %{}}
  def init_continue(output_oracle, caller)
      when caller in [
             Indexer.Fetcher.Optimism.Deposit,
             Indexer.Fetcher.Optimism.WithdrawalEvent,
             Indexer.Fetcher.Optimism.OutputRoot
           ] do
    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    {contract_name, table_name, start_block_note} =
      case caller do
        Indexer.Fetcher.Optimism.Deposit ->
          {"Optimism Portal", "op_deposits", "Deposits"}

        Indexer.Fetcher.Optimism.WithdrawalEvent ->
          {"Optimism Portal", "op_withdrawal_events", "Withdrawals L1"}

        _ ->
          {"Output Oracle", "op_output_roots", "Output Roots"}
      end

    optimism_env = Application.get_all_env(:indexer)[__MODULE__]
    system_config = optimism_env[:optimism_l1_system_config]
    optimism_l1_rpc = l1_rpc_url()

    with {:system_config_valid, true} <- {:system_config_valid, Helper.address_correct?(system_config)},
         _ <- RollupL1ReorgMonitor.wait_for_start(caller),
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_l1_rpc)},
         json_rpc_named_arguments = json_rpc_named_arguments(optimism_l1_rpc),
         {optimism_portal, start_block_l1} <- read_system_config(system_config, json_rpc_named_arguments),
         {:contract_is_valid, true} <-
           {:contract_is_valid, caller != Indexer.Fetcher.Optimism.OutputRoot or Helper.address_correct?(output_oracle)},
         true <- start_block_l1 > 0,
         {last_l1_block_number, last_l1_transaction_hash, last_l1_transaction} <-
           caller.get_last_l1_item(json_rpc_named_arguments),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         {:l1_transaction_not_found, false} <-
           {:l1_transaction_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_transaction)},
         {:ok, block_check_interval, last_safe_block} <- get_block_check_interval(json_rpc_named_arguments) do
      contract_address =
        if caller == Indexer.Fetcher.Optimism.OutputRoot do
          output_oracle
        else
          optimism_portal
        end

      start_block = max(start_block_l1, last_l1_block_number)

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         contract_address: contract_address,
         block_check_interval: block_check_interval,
         start_block: start_block,
         end_block: last_safe_block,
         json_rpc_named_arguments: json_rpc_named_arguments,
         eth_get_logs_range_size: optimism_env[:l1_eth_get_logs_range_size],
         stop: false
       }}
    else
      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, %{}}

      {:system_config_valid, false} ->
        Logger.error("SystemConfig contract address is invalid or undefined.")
        {:stop, :normal, %{}}

      {:contract_is_valid, false} ->
        Logger.error("#{contract_name} contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:start_block_l1_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and #{table_name} table.")
        {:stop, :normal, %{}}

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash, last safe/latest block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        {:stop, :normal, %{}}

      {:l1_transaction_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check #{table_name} table."
        )

        {:stop, :normal, %{}}

      nil ->
        Logger.error("Cannot read SystemConfig contract and fallback envs are not correctly defined.")
        {:stop, :normal, %{}}

      _ ->
        Logger.error("#{start_block_note} Start Block is invalid or zero.")
        {:stop, :normal, %{}}
    end
  end

  def repeated_request(req, error_message, json_rpc_named_arguments, retries) do
    Helper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  @doc """
    Reads some public getters of SystemConfig contract and returns retrieved values.
    Gets `OptimismPortal` contract address from the `SystemConfig` contract and
    the number of a start block (from which all Optimism fetchers should start).

    If SystemConfig has obsolete implementation, the values are fallen back from the corresponding
    env variables (INDEXER_OPTIMISM_L1_PORTAL_CONTRACT and INDEXER_OPTIMISM_L1_START_BLOCK).

    ## Parameters
    - `contract_address`: An address of SystemConfig contract.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - A tuple of OptimismPortal contract address and start block: {optimism_portal, start_block}.
    - `nil` in case of error.
  """
  @spec read_system_config(binary(), list()) :: {binary(), non_neg_integer()} | nil
  def read_system_config(contract_address, json_rpc_named_arguments) do
    requests = [
      # optimismPortal() public getter
      Contract.eth_call_request("0x0a49cb03", contract_address, 0, nil, nil),
      # startBlock() public getter
      Contract.eth_call_request("0x48cd4cb1", contract_address, 1, nil, nil)
    ]

    error_message = &"Cannot call public getters of SystemConfig. Error: #{inspect(&1)}"

    env = Application.get_all_env(:indexer)[__MODULE__]
    fallback_start_block = env[:start_block_l1]

    {optimism_portal, start_block} =
      case Helper.repeated_call(
             &json_rpc/2,
             [requests, json_rpc_named_arguments],
             error_message,
             Helper.finite_retries_number()
           ) do
        {:ok, responses} ->
          optimism_portal_result = Map.get(Enum.at(responses, 0), :result)

          optimism_portal =
            with {:nil_result, true, _} <- {:nil_result, is_nil(optimism_portal_result), optimism_portal_result},
                 {:fallback_defined, true} <- {:fallback_defined, Helper.address_correct?(env[:portal])} do
              env[:portal]
            else
              {:nil_result, false, portal} ->
                "0x000000000000000000000000" <> optimism_portal = portal
                "0x" <> optimism_portal

              {:fallback_defined, false} ->
                nil
            end

          start_block =
            responses
            |> Enum.at(1)
            |> Map.get(:result, fallback_start_block)
            |> quantity_to_integer()

          {optimism_portal, start_block}

        _ ->
          {env[:portal], fallback_start_block}
      end

    if Helper.address_correct?(optimism_portal) and !is_nil(start_block) do
      {String.downcase(optimism_portal), start_block}
    end
  end

  @doc """
    Returns L1 RPC URL for an OP module.
  """
  @spec l1_rpc_url() :: binary() | nil
  def l1_rpc_url do
    Application.get_all_env(:indexer)[__MODULE__][:optimism_l1_rpc]
  end

  @doc """
    Determines if `Indexer.Fetcher.RollupL1ReorgMonitor` module must be up
    before an OP fetcher starts.

    ## Returns
    - `true` if the reorg monitor must be active, `false` otherwise.
  """
  @spec requires_l1_reorg_monitor?() :: boolean()
  def requires_l1_reorg_monitor? do
    optimism_config = Application.get_all_env(:indexer)[__MODULE__]
    not is_nil(optimism_config[:optimism_l1_system_config])
  end

  @doc """
    Determines the last saved block number, the last saved transaction hash, and the transaction info for
    a certain entity defined by the passed functions.

    Used by the OP fetcher modules to start fetching from a correct block number
    after reorg has occurred.

    ## Parameters
    - `layer`: Just for logging purposes. Can be `:L1` or `:L2` depending on the layer of the entity.
    - `last_block_number_query_fun`: A function which will be called to form database query
                                     to get the latest item in the corresponding database table.
    - `remove_query_fun`: A function which will be called to form database query to remove the entity rows
                          created due to reorg from the corresponding table.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
                                  Used to get transaction info by its hash from the RPC node.
                                  Can be `nil` if the transaction info is not needed.

    ## Returns
    - A tuple `{last_block_number, last_transaction_hash, last_transaction}` where
      `last_block_number` is the last block number found in the corresponding table (0 if not found),
      `last_transaction_hash` is the last transaction hash found in the corresponding table (nil if not found),
      `last_transaction` is the transaction info got from the RPC (nil if not found or not needed).
    - A tuple `{:error, message}` in case the `eth_getTransactionByHash` RPC request failed.
  """
  @spec get_last_item(:L1 | :L2, function(), function(), EthereumJSONRPC.json_rpc_named_arguments() | nil) ::
          {non_neg_integer(), binary() | nil, map() | nil} | {:error, any()}
  def get_last_item(layer, last_block_number_query_fun, remove_query_fun, json_rpc_named_arguments \\ nil)
      when is_function(last_block_number_query_fun, 0) and is_function(remove_query_fun, 1) do
    {last_block_number, last_transaction_hash} =
      last_block_number_query_fun.()
      |> Repo.one()
      |> Kernel.||({0, nil})

    with {:empty_hash, false} <- {:empty_hash, is_nil(last_transaction_hash)},
         {:empty_json_rpc_named_arguments, false} <-
           {:empty_json_rpc_named_arguments, is_nil(json_rpc_named_arguments)},
         {:ok, last_transaction} <- get_transaction_by_hash(last_transaction_hash, json_rpc_named_arguments),
         {:empty_transaction, false} <- {:empty_transaction, is_nil(last_transaction)} do
      {last_block_number, last_transaction_hash, last_transaction}
    else
      {:empty_hash, true} ->
        {last_block_number, nil, nil}

      {:empty_json_rpc_named_arguments, true} ->
        {last_block_number, last_transaction_hash, nil}

      {:error, _} = error ->
        error

      {:empty_transaction, true} ->
        Logger.error(
          "Cannot find last #{layer} transaction from RPC by its hash (#{last_transaction_hash}). Probably, there was a reorg on #{layer} chain. Trying to check preceding transaction..."
        )

        last_block_number
        |> remove_query_fun.()
        |> Repo.delete_all()

        get_last_item(layer, last_block_number_query_fun, remove_query_fun, json_rpc_named_arguments)
    end
  end

  @doc """
    Sends HTTP request to Chainscout API to get instance info by its chain ID.

    ## Parameters
    - `chain_id`: The chain ID for which the instance info should be retrieved. Can be defined as String or Integer.
    - `chainscout_api_url`: URL defined in INDEXER_OPTIMISM_CHAINSCOUT_API_URL env variable. If `nil`, the function returns `nil`.

    ## Returns
    - A map with instance info (instance_url, chain_id, chain_name, chain_logo) in case of success.
    - `nil` in case of failure.
  """
  @spec get_instance_info_by_chain_id(String.t() | non_neg_integer(), String.t() | nil) :: map() | nil
  def get_instance_info_by_chain_id(chain_id, nil) do
    Logger.error(
      "Unknown instance URL for chain ID #{chain_id}. Please, define that in INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP or define INDEXER_OPTIMISM_CHAINSCOUT_API_URL."
    )

    nil
  end

  def get_instance_info_by_chain_id(chain_id, chainscout_api_url) do
    url =
      if is_integer(chain_id) do
        chainscout_api_url <> Integer.to_string(chain_id)
      else
        chainscout_api_url <> chain_id
      end

    with {:ok, %HTTPoison.Response{body: body, status_code: 200}} <- HTTPoison.get(url),
         {:ok, response} <- Jason.decode(body),
         explorer = response |> Map.get("explorers", []) |> Enum.at(0),
         false <- is_nil(explorer),
         explorer_url = Map.get(explorer, "url"),
         false <- is_nil(explorer_url) do
      %{
        instance_url: String.trim_trailing(explorer_url, "/"),
        chain_id: chain_id,
        chain_name: Map.get(response, "name"),
        chain_logo: Map.get(response, "logo")
      }
    else
      true ->
        Logger.error("Cannot get explorer URL from #{url}")
        nil

      other ->
        Logger.error("Cannot get HTTP response from #{url}. Reason: #{inspect(other)}")
        nil
    end
  end
end
