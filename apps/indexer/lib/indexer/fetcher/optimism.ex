defmodule Indexer.Fetcher.Optimism do
  @moduledoc """
  Contains common functions for Optimism* fetchers.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC,
    only: [
      fetch_block_number_by_tag_op_version: 2,
      json_rpc: 2,
      integer_to_quantity: 1,
      quantity_to_integer: 1,
      request: 1
    ]

  import Explorer.Helper, only: [parse_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias Indexer.Helper

  @fetcher_name :optimism
  @block_check_interval_range_size 100
  @eth_get_logs_range_size 1000
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
  Calculates average block time in milliseconds (based on the latest 100 blocks) divided by 2.
  Sends corresponding requests to the RPC node.
  Returns a tuple {:ok, block_check_interval, last_safe_block}
  where `last_safe_block` is the number of the recent `safe` or `latest` block (depending on which one is available).
  Returns {:error, description} in case of error.
  """
  @spec get_block_check_interval(list()) :: {:ok, non_neg_integer(), non_neg_integer()} | {:error, any()}
  def get_block_check_interval(json_rpc_named_arguments) do
    {last_safe_block, _} = get_safe_block(json_rpc_named_arguments)

    first_block = max(last_safe_block - @block_check_interval_range_size, 1)

    with {:ok, first_block_timestamp} <-
           get_block_timestamp_by_number(first_block, json_rpc_named_arguments, Helper.infinite_retries_number()),
         {:ok, last_safe_block_timestamp} <-
           get_block_timestamp_by_number(last_safe_block, json_rpc_named_arguments, Helper.infinite_retries_number()) do
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
  Fetches block number by its tag (e.g. `latest` or `safe`) using RPC request.
  Performs a specified number of retries (up to) if the first attempt returns error.
  """
  @spec get_block_number_by_tag(binary(), list(), non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_block_number_by_tag(tag, json_rpc_named_arguments, retries \\ @finite_retries_number) do
    error_message = &"Cannot fetch #{tag} block number. Error: #{inspect(&1)}"

    Helper.repeated_call(
      &fetch_block_number_by_tag_op_version/2,
      [tag, json_rpc_named_arguments],
      error_message,
      retries
    )
  end

  @doc """
  Tries to get `safe` block number from the RPC node.
  If it's not available, gets the `latest` one.
  Returns a tuple of `{block_number, is_latest}`
  where `is_latest` is true if the `safe` is not available.
  """
  @spec get_safe_block(list()) :: {non_neg_integer(), boolean()}
  def get_safe_block(json_rpc_named_arguments) do
    case get_block_number_by_tag("safe", json_rpc_named_arguments) do
      {:ok, safe_block} ->
        {safe_block, false}

      {:error, :not_found} ->
        {:ok, latest_block} =
          get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number())

        {latest_block, true}
    end
  end

  defp get_block_timestamp_by_number_inner(number, json_rpc_named_arguments) do
    result =
      %{id: 0, number: number}
      |> ByNumber.request(false)
      |> json_rpc(json_rpc_named_arguments)

    with {:ok, block} <- result,
         false <- is_nil(block),
         timestamp <- Map.get(block, "timestamp"),
         false <- is_nil(timestamp) do
      {:ok, quantity_to_integer(timestamp)}
    else
      {:error, message} ->
        {:error, message}

      true ->
        {:error, "RPC returned nil."}
    end
  end

  @doc """
  Fetches block timestamp by its number using RPC request.
  Performs a specified number of retries (up to) if the first attempt returns error.
  """
  @spec get_block_timestamp_by_number(non_neg_integer(), list(), non_neg_integer()) ::
          {:ok, non_neg_integer()} | {:error, any()}
  def get_block_timestamp_by_number(number, json_rpc_named_arguments, retries \\ @finite_retries_number) do
    func = &get_block_timestamp_by_number_inner/2
    args = [number, json_rpc_named_arguments]
    error_message = &"Cannot fetch block ##{number} or its timestamp. Error: #{inspect(&1)}"
    Helper.repeated_call(func, args, error_message, retries)
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

  def get_logs_range_size do
    @eth_get_logs_range_size
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
        url: optimism_l1_rpc,
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end

  def init_continue(env, contract_address, caller)
      when caller in [Indexer.Fetcher.Optimism.WithdrawalEvent, Indexer.Fetcher.Optimism.OutputRoot] do
    {contract_name, table_name, start_block_note} =
      if caller == Indexer.Fetcher.Optimism.WithdrawalEvent do
        {"Optimism Portal", "op_withdrawal_events", "Withdrawals L1"}
      else
        {"Output Oracle", "op_output_roots", "Output Roots"}
      end

    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         {:reorg_monitor_started, true} <-
           {:reorg_monitor_started, !is_nil(Process.whereis(Indexer.Fetcher.RollupL1ReorgMonitor))},
         optimism_l1_rpc = Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism][:optimism_l1_rpc],
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_l1_rpc)},
         {:contract_is_valid, true} <- {:contract_is_valid, Helper.address_correct?(contract_address)},
         start_block_l1 = parse_integer(env[:start_block_l1]),
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0,
         {last_l1_block_number, last_l1_transaction_hash} <- caller.get_last_l1_item(),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         json_rpc_named_arguments = json_rpc_named_arguments(optimism_l1_rpc),
         {:ok, last_l1_tx} <- get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments),
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_tx)},
         {:ok, block_check_interval, last_safe_block} <- get_block_check_interval(json_rpc_named_arguments) do
      start_block = max(start_block_l1, last_l1_block_number)

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         contract_address: contract_address,
         block_check_interval: block_check_interval,
         start_block: start_block,
         end_block: last_safe_block,
         json_rpc_named_arguments: json_rpc_named_arguments
       }}
    else
      {:start_block_l1_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, %{}}

      {:reorg_monitor_started, false} ->
        Logger.error("Cannot start this process as reorg monitor in Indexer.Fetcher.Optimism is not started.")
        {:stop, :normal, %{}}

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
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

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check #{table_name} table."
        )

        {:stop, :normal, %{}}

      _ ->
        Logger.error("#{start_block_note} Start Block is invalid or zero.")
        {:stop, :normal, %{}}
    end
  end

  def repeated_request(req, error_message, json_rpc_named_arguments, retries) do
    Helper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end
end
