defmodule Indexer.Fetcher.Optimism.Withdrawal do
  @moduledoc """
  Fills op_withdrawals DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [decode_data: 2, parse_integer: 1]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Optimism.Withdrawal, as: OptimismWithdrawal
  alias Indexer.Fetcher.Optimism
  alias Indexer.Helper

  @fetcher_name :optimism_withdrawals
  @counter_type "optimism_withdrawals_fetcher_last_l2_block_hash"

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
  def init(args) do
    {:ok, %{}, {:continue, args[:json_rpc_named_arguments]}}
  end

  # Initialization function which is used instead of `init` to avoid Supervisor's stop in case of any critical issues
  # during initialization. It checks the values of env variables, gets last L2 block number to start the scanning from,
  # and calculates an average block check interval (for realtime part of the logic).
  #
  # When the initialization succeeds, the `:continue` message is sent to GenServer to start the catchup loop
  # retrieving and saving the withdrawal events.
  #
  # ## Parameters
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection to L2 RPC node.
  # - `state`: Initial state of the fetcher (empty map when starting).
  #
  # ## Returns
  # - `{:noreply, state}` when the initialization is successful and the fetching can start. The `state` contains
  #                       necessary parameters needed for the fetching.
  # - `{:stop, :normal, %{}}` in case of error.
  @impl GenServer
  @spec handle_continue(EthereumJSONRPC.json_rpc_named_arguments(), map()) ::
          {:noreply, map()} | {:stop, :normal, map()}
  def handle_continue(json_rpc_named_arguments, state) do
    Logger.metadata(fetcher: @fetcher_name)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_l2_undefined, false} <- {:start_block_l2_undefined, is_nil(env[:start_block_l2])},
         {:message_passer_valid, true} <- {:message_passer_valid, Helper.address_correct?(env[:message_passer])},
         start_block_l2 = parse_integer(env[:start_block_l2]),
         false <- is_nil(start_block_l2),
         true <- start_block_l2 > 0,
         {last_l2_block_number, last_l2_transaction_hash, last_l2_transaction} <-
           get_last_l2_item(json_rpc_named_arguments),
         {safe_block, safe_block_is_latest} = Helper.get_safe_block(json_rpc_named_arguments),
         {:start_block_l2_valid, true} <-
           {:start_block_l2_valid,
            (start_block_l2 <= last_l2_block_number || last_l2_block_number == 0) && start_block_l2 <= safe_block},
         {:l2_transaction_not_found, false} <-
           {:l2_transaction_not_found, !is_nil(last_l2_transaction_hash) && is_nil(last_l2_transaction)} do
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         start_block: max(start_block_l2, last_l2_block_number),
         safe_block: safe_block,
         safe_block_is_latest: safe_block_is_latest,
         message_passer: env[:message_passer],
         json_rpc_named_arguments: json_rpc_named_arguments,
         eth_get_logs_range_size:
           Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism][:l2_eth_get_logs_range_size]
       }}
    else
      {:start_block_l2_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, state}

      {:message_passer_valid, false} ->
        Logger.error("L2ToL1MessagePasser contract address is invalid or not defined.")
        {:stop, :normal, state}

      {:start_block_l2_valid, false} ->
        Logger.error("Invalid L2 Start Block value. Please, check the value and op_withdrawals table.")
        {:stop, :normal, state}

      {:error, error_data} ->
        Logger.error("Cannot get last L2 transaction from RPC by its hash due to RPC error: #{inspect(error_data)}")

        {:stop, :normal, state}

      {:l2_transaction_not_found, true} ->
        Logger.error(
          "Cannot find last L2 transaction from RPC by its hash. Probably, there was a reorg on L2 chain. Please, check op_withdrawals table."
        )

        {:stop, :normal, state}

      _ ->
        Logger.error("Withdrawals L2 Start Block is invalid or zero.")
        {:stop, :normal, state}
    end
  end

  # Performs the catchup handling loop for the specified block range. The block range is split into chunks.
  # Max size of a chunk is defined by INDEXER_OPTIMISM_L2_ETH_GET_LOGS_RANGE_SIZE env variable.
  #
  # ## Parameters
  # - `:continue`: The GenServer message.
  # - `state`: The current state of the fetcher containing block range, max chunk size, etc.
  #
  # ## Returns
  # - `{:stop, :normal, state}` tuple.
  @impl GenServer
  def handle_info(
        :continue,
        %{
          start_block: start_block,
          safe_block: safe_block,
          safe_block_is_latest: safe_block_is_latest,
          message_passer: message_passer,
          json_rpc_named_arguments: json_rpc_named_arguments,
          eth_get_logs_range_size: eth_get_logs_range_size
        } = state
      ) do
    # find and fill all events between start_block and "safe" block
    # the "safe" block can be "latest" (when safe_block_is_latest == true)
    fill_block_range(start_block, safe_block, message_passer, json_rpc_named_arguments, eth_get_logs_range_size)

    if not safe_block_is_latest do
      # find and fill all events between "safe" and "latest" block (excluding "safe")
      {:ok, latest_block} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments)

      fill_block_range(
        safe_block + 1,
        latest_block,
        message_passer,
        json_rpc_named_arguments,
        eth_get_logs_range_size
      )
    end

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @doc """
  Removes all withdrawals created starting from the given block.

  ## Parameters
  - `starting_block`: The starting block number.

  ## Returns
  - Nothing.
  """
  @spec remove(non_neg_integer()) :: any()
  def remove(starting_block) do
    Repo.delete_all(from(w in OptimismWithdrawal, where: w.l2_block_number >= ^starting_block))
    LastFetchedCounter.delete(@counter_type)
  end

  def event_to_withdrawal(second_topic, data, l2_transaction_hash, l2_block_number) do
    [_value, _gas_limit, _data, hash] = decode_data(data, [{:uint, 256}, {:uint, 256}, :bytes, {:bytes, 32}])

    msg_nonce =
      second_topic
      |> Helper.log_topic_to_string()
      |> quantity_to_integer()
      |> Decimal.new()

    %{
      msg_nonce: msg_nonce,
      hash: hash,
      l2_transaction_hash: l2_transaction_hash,
      l2_block_number: quantity_to_integer(l2_block_number)
    }
  end

  defp find_and_save_withdrawals(message_passer, block_start, block_end, json_rpc_named_arguments) do
    message_passed_event = OptimismWithdrawal.message_passed_event()

    {:ok, result} =
      Helper.get_logs(
        block_start,
        block_end,
        message_passer,
        [message_passed_event],
        json_rpc_named_arguments,
        0,
        Helper.infinite_retries_number()
      )

    withdrawals =
      Enum.map(result, fn event ->
        event_to_withdrawal(
          Enum.at(event["topics"], 1),
          event["data"],
          event["transactionHash"],
          event["blockNumber"]
        )
      end)

    {:ok, _} =
      Chain.import(%{
        optimism_withdrawals: %{params: withdrawals},
        timeout: :infinity
      })

    Enum.count(withdrawals)
  end

  defp fill_block_range(
         l2_block_start,
         l2_block_end,
         _message_passer,
         _json_rpc_named_arguments,
         _eth_get_logs_range_size
       )
       when l2_block_start > l2_block_end, do: nil

  defp fill_block_range(
         l2_block_start,
         l2_block_end,
         message_passer,
         json_rpc_named_arguments,
         eth_get_logs_range_size
       ) do
    chunks_number = ceil((l2_block_end - l2_block_start + 1) / eth_get_logs_range_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    Enum.each(chunk_range, fn current_chunk ->
      chunk_start = l2_block_start + eth_get_logs_range_size * current_chunk
      chunk_end = min(chunk_start + eth_get_logs_range_size - 1, l2_block_end)

      Helper.log_blocks_chunk_handling(chunk_start, chunk_end, l2_block_start, l2_block_end, nil, :L2)

      withdrawals_count =
        find_and_save_withdrawals(
          message_passer,
          chunk_start,
          chunk_end,
          json_rpc_named_arguments
        )

      Helper.log_blocks_chunk_handling(
        chunk_start,
        chunk_end,
        l2_block_start,
        l2_block_end,
        "#{withdrawals_count} MessagePassed event(s)",
        :L2
      )

      Optimism.set_last_block_hash_by_number(chunk_end, @counter_type, json_rpc_named_arguments)
    end)
  end

  # Determines the last saved L2 block number, the last saved transaction hash, and the transaction info for withdrawals.
  #
  # Utilized to start fetching from a correct block number after reorg has occurred.
  #
  # ## Parameters
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #                               Used to get transaction info by its hash from the RPC node.
  #
  # ## Returns
  # - A tuple `{last_block_number, last_transaction_hash, last_transaction}` where
  #   `last_block_number` is the last block number found in the corresponding table (0 if not found),
  #   `last_transaction_hash` is the last transaction hash found in the corresponding table (nil if not found),
  #   `last_transaction` is the transaction info got from the RPC (nil if not found).
  # - A tuple `{:error, message}` in case the `eth_getTransactionByHash` RPC request failed.
  @spec get_last_l2_item(EthereumJSONRPC.json_rpc_named_arguments()) ::
          {non_neg_integer(), binary() | nil, map() | nil} | {:error, any()}
  defp get_last_l2_item(json_rpc_named_arguments) do
    Optimism.get_last_item(
      :L2,
      &OptimismWithdrawal.last_withdrawal_l2_block_number_query/0,
      &OptimismWithdrawal.remove_withdrawals_query/1,
      json_rpc_named_arguments,
      @counter_type
    )
  end
end
