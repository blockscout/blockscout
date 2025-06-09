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
      id_to_params: 1,
      integer_to_quantity: 1,
      quantity_to_integer: 1
    ]

  alias EthereumJSONRPC.Block.{ByHash, ByNumber}
  alias EthereumJSONRPC.{Blocks, Contract}
  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.RollupReorgMonitorQueue
  alias Explorer.Repo
  alias Indexer.Fetcher.RollupL1ReorgMonitor
  alias Indexer.Helper

  @empty_hash "0x0000000000000000000000000000000000000000000000000000000000000000"

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
    :ignore
  end

  @doc """
  Fetches the chain id from the RPC (or cache).

  ## Parameters
  - `retry_attempt`: How many retries have already been done.

  ## Returns
  - The chain id as unsigned integer.
  - `nil` if the request failed.
  """
  @spec fetch_chain_id(non_neg_integer()) :: non_neg_integer() | nil
  def fetch_chain_id(retry_attempt \\ 0) do
    case ChainId.get_id() do
      nil ->
        Logger.error("Cannot read `eth_chainId`. Retrying...")
        Helper.pause_before_retry(retry_attempt)
        fetch_chain_id(retry_attempt + 1)

      chain_id ->
        chain_id
    end
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
    if caller != Indexer.Fetcher.Optimism.OutputRoot do
      # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
      :timer.sleep(2000)
    end

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
         json_rpc_named_arguments = Helper.json_rpc_named_arguments(optimism_l1_rpc),
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
         {:ok, block_check_interval, last_safe_block} <- Helper.get_block_check_interval(json_rpc_named_arguments) do
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
    Updates the last handled block hash by a fetcher.
    The new block hash is written to the `last_fetched_counters` table.

    ## Parameters
    - `block_hash`: The hash of the block in the form of `0x` string.
    - `counter_type`: Name of a record in the `last_fetched_counters` table to set the last known block hash to.

    ## Returns
    - nothing
  """
  @spec set_last_block_hash(binary(), binary()) :: any()
  def set_last_block_hash(nil, _), do: nil

  def set_last_block_hash(block_hash, counter_type) do
    {block_hash_integer, ""} =
      block_hash
      |> String.trim_leading("0x")
      |> Integer.parse(16)

    LastFetchedCounter.upsert(%{
      counter_type: counter_type,
      value: block_hash_integer
    })
  end

  @doc """
    Updates the last handled block hash by a fetcher.
    The new block hash is written to the `last_fetched_counters` table.
    This function accepts the block number for which the block hash must be determined.
    If RPC node returns `nil` as the successful result, this function doesn't do anything.

    ## Parameters
    - `block_number`: The number of the block.
    - `counter_type`: Name of a record in the `last_fetched_counters` table to set the last known block hash to.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - nothing
  """
  @spec set_last_block_hash_by_number(non_neg_integer(), binary(), EthereumJSONRPC.json_rpc_named_arguments()) :: any()
  def set_last_block_hash_by_number(block_number, counter_type, json_rpc_named_arguments) do
    block =
      [block_number]
      |> get_blocks_by_numbers(json_rpc_named_arguments, Helper.infinite_retries_number())
      |> List.first()

    if not is_nil(block) do
      block
      |> Map.get("hash")
      |> set_last_block_hash(counter_type)
    end
  end

  @doc """
    Takes the last block hash from the `last_fetched_counters` table for the given counter type,
    gets its number using RPC request, and returns the number. Returns `nil` if the last block hash is not defined in the `last_fetched_counters` table,
    or the block hash is not valid anymore (due to a reorg), or the block number cannot be retrieved from RPC.

    If the number cannot be retrieved using this function, the calling code must use another approach to get the last block number,
    e.g. getting the last entity row from the corresponding database table.

    ## Parameters
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection. If `nil`, the function does nothing and returns `nil`.
    - `counter_type`: The counter type to read the last counter for.

    ## Returns
    - The integer block number in case of success.
    - `nil` otherwise.
  """
  @spec get_last_block_number_from_last_fetched_counter(EthereumJSONRPC.json_rpc_named_arguments() | nil, binary()) ::
          non_neg_integer() | nil
  def get_last_block_number_from_last_fetched_counter(nil, _), do: nil

  def get_last_block_number_from_last_fetched_counter(json_rpc_named_arguments, counter_type) do
    last_block_hash =
      "0x" <>
        (counter_type
         |> LastFetchedCounter.get()
         |> Decimal.to_integer()
         |> Integer.to_string(16)
         |> String.pad_leading(64, "0"))

    if last_block_hash != @empty_hash do
      case get_block_by_hash(last_block_hash, json_rpc_named_arguments) do
        {:ok, nil} ->
          # it seems there was a reorg, so we need to reset the block hash in the counter
          # and then use another approach taking the block number from a corresponding table
          set_last_block_hash(@empty_hash, counter_type)
          nil

        {:ok, last_block} ->
          # the block hash is actual, so use the block number
          last_block
          |> Map.get("number")
          |> quantity_to_integer()

        {:error, _} ->
          # something went wrong, so use another approach
          nil
      end
    end
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
    - `counter_type`: Name of a record in the `last_fetched_counters` table to read the last known block hash from.

    ## Returns
    - A tuple `{last_block_number, last_transaction_hash, last_transaction}` where
      `last_block_number` is the last block number found in the corresponding table (0 if not found),
      `last_transaction_hash` is the last transaction hash found in the corresponding table (nil if not found),
      `last_transaction` is the transaction info got from the RPC (nil if not found or not needed).
    - A tuple `{:error, message}` in case the `eth_getTransactionByHash` RPC request failed.
  """
  @spec get_last_item(:L1 | :L2, function(), function(), EthereumJSONRPC.json_rpc_named_arguments() | nil, binary()) ::
          {non_neg_integer(), binary() | nil, map() | nil} | {:error, any()}
  def get_last_item(layer, last_block_number_query_fun, remove_query_fun, json_rpc_named_arguments, counter_type)
      when is_function(last_block_number_query_fun, 0) and is_function(remove_query_fun, 1) do
    last_block_number = get_last_block_number_from_last_fetched_counter(json_rpc_named_arguments, counter_type)

    if is_nil(last_block_number) do
      {last_block_number, last_transaction_hash} =
        last_block_number_query_fun.()
        |> Repo.one()
        |> Kernel.||({0, nil})

      with {:empty_hash, false} <- {:empty_hash, is_nil(last_transaction_hash)},
           {:empty_json_rpc_named_arguments, false} <-
             {:empty_json_rpc_named_arguments, is_nil(json_rpc_named_arguments)},
           {:ok, last_transaction} <- Helper.get_transaction_by_hash(last_transaction_hash, json_rpc_named_arguments),
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

          get_last_item(layer, last_block_number_query_fun, remove_query_fun, json_rpc_named_arguments, counter_type)
      end
    else
      {last_block_number, nil, nil}
    end
  end

  @doc """
    Fetches block data by its hash using RPC request.

    ## Parameters
    - `hash`: The block hash.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - `{:ok, block}` tuple in case of success.
    - `{:error, message}` tuple in case of failure.
  """
  @spec get_block_by_hash(binary(), EthereumJSONRPC.json_rpc_named_arguments()) :: {:ok, any()} | {:error, any()}
  def get_block_by_hash(hash, json_rpc_named_arguments) do
    req = ByHash.request(%{id: 0, hash: hash}, false)

    error_message = &"eth_getBlockByHash failed. Error: #{inspect(&1)}"

    Helper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, Helper.infinite_retries_number())
  end

  @doc """
    Fetches blocks from RPC by their numbers.

    ## Parameters
    - `block_numbers`: The list of block numbers (each number can be integer or in form of `0x` quantity).
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
    - `retries`: Number of retry attempts if the request fails.

    ## Returns
    - The list of blocks. The list will be empty if all retries to RPC were failed.
  """
  @spec get_blocks_by_numbers(list(), EthereumJSONRPC.json_rpc_named_arguments(), non_neg_integer()) :: list()
  def get_blocks_by_numbers(block_numbers, json_rpc_named_arguments, retries) do
    request =
      block_numbers
      |> Stream.map(fn block_number -> %{number: integer_to_quantity(block_number)} end)
      |> id_to_params()
      |> Blocks.requests(&ByNumber.request(&1, false, false))

    error_message = &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(request)}"

    case Helper.repeated_call(&json_rpc/2, [request, json_rpc_named_arguments], error_message, retries) do
      {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
      {:error, _} -> []
    end
  end

  @doc """
    Reads reorg block numbers queue for the specified module and pops the block numbers from that
    finding the earliest one.

    ## Parameters
    - `module`: The module for which the queue should be read.
    - `handle_reorg_func`: Reference to a local `handle_reorg` function.

    ## Returns
    - The earliest reorg block number.
    - `nil` if the queue is empty.
  """
  @spec handle_reorgs_queue(module(), function()) :: non_neg_integer() | nil
  def handle_reorgs_queue(module, handle_reorg_func) do
    reorg_block_number =
      Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), nil, fn _i, acc ->
        number = RollupReorgMonitorQueue.reorg_block_pop(module)

        if is_nil(number) do
          {:halt, acc}
        else
          {:cont, min(number, acc)}
        end
      end)

    handle_reorg_func.(reorg_block_number)

    reorg_block_number
  end

  @doc """
    Catches L2 reorg block from the realtime block fetcher and keeps it in a queue to handle that by the main loop.

    ## Parameters
    - `reorg_block_number`: The number of reorg block.
    - `module`: The module for which the reorg block number should be added to queue.
                The module must have a public `fetcher_name()` function.

    ## Returns
    - nothing.
  """
  @spec handle_realtime_l2_reorg(non_neg_integer(), module()) :: any()
  def handle_realtime_l2_reorg(reorg_block_number, module) do
    Logger.warning("L2 reorg was detected at block #{reorg_block_number}.", fetcher: module.fetcher_name())
    RollupReorgMonitorQueue.reorg_block_push(reorg_block_number, module)
  end

  @doc """
    Catches realtime L2 blocks from `:blocks, :realtime` subscription and forms a new realtime block range to be handled by a loop handler
    in `Indexer.Fetcher.Optimism.Interop.Message`, `Indexer.Fetcher.Optimism.Interop.MessageFailed`, or `Indexer.Fetcher.Optimism.EIP1559ConfigUpdate` module.

    ## Parameters
    - `blocks`: The list of new realtime L2 blocks arrived.
    - `state`: The current module state containing the current block range, handling mode (:realtime, :continue, or :catchup), and the last known L2 block number.

    ## Returns
    - `{:noreply, state}` tuple where the `state` contains updated parameters (block range, last realtime block number, etc.)
  """
  @spec handle_realtime_blocks(list(), map()) :: {:noreply, map()}
  def handle_realtime_blocks([], state) do
    Logger.info("Got an empty list of new realtime block numbers")
    {:noreply, state}
  end

  def handle_realtime_blocks(
        blocks,
        %{realtime_range: realtime_range, mode: mode, last_realtime_block_number: last_realtime_block_number} = state
      ) do
    {new_min, new_max} =
      blocks
      |> Enum.map(fn block -> block.number end)
      |> Enum.min_max()

    if new_min != new_max do
      Logger.info("Got a range of new realtime block numbers: #{inspect(new_min..new_max)}")
    else
      Logger.info("Got a new realtime block number #{new_max}")
    end

    {start_block_number, end_block_number} =
      case realtime_range do
        nil -> {new_min, new_max}
        prev_min..prev_max//_ -> {min(prev_min, new_min), max(prev_max, new_max)}
      end

    start_block_number_updated =
      if last_realtime_block_number < start_block_number do
        last_realtime_block_number + 1
      else
        start_block_number
      end

    new_realtime_range = Range.new(start_block_number_updated, end_block_number)

    if mode == :realtime do
      Logger.info("The current realtime range is #{inspect(new_realtime_range)}. Starting to handle that...")

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         state
         | start_block_number: start_block_number_updated,
           end_block_number: end_block_number,
           mode: :continue,
           realtime_range: nil,
           last_realtime_block_number: new_max
       }}
    else
      {:noreply, %{state | realtime_range: new_realtime_range, last_realtime_block_number: new_max}}
    end
  end

  @doc """
    Outputs log messages about finishing catchup loop and starting realtime mode.

    ## Parameters
    - `start_block_number`: The first block number of the block range for which the loop is finished.
    - `start_block_number`: The last block number of the block range for which the loop is finished.

    ## Returns
    - :ok
  """
  @spec log_catchup_loop_finished(non_neg_integer(), non_neg_integer()) :: :ok
  def log_catchup_loop_finished(start_block_number, end_block_number) do
    Logger.info("The fetcher catchup loop for the range #{inspect(start_block_number..end_block_number)} finished.")
    Logger.info("Switching to realtime mode...")
  end

  @doc """
    Outputs log message with error and sleeps before the next retry.

    ## Parameters
    - `error_message`: The error message to output.

    ## Returns
    - :ok
  """
  @spec log_error_message_with_retry_sleep(String.t()) :: :ok
  def log_error_message_with_retry_sleep(error_message) do
    Logger.error("#{error_message} Retrying...")
    :timer.sleep(3000)
  end
end
