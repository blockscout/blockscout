defmodule Indexer.Fetcher.Optimism.WithdrawalEvent do
  @moduledoc """
  Fills op_withdrawal_events DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [id_to_params: 1, json_rpc: 2, quantity_to_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Optimism.WithdrawalEvent
  alias Explorer.Chain.RollupReorgMonitorQueue
  alias Indexer.Fetcher.Optimism
  alias Indexer.Helper

  @fetcher_name :optimism_withdrawal_events
  @counter_type "optimism_withdrawal_events_fetcher_last_l1_block_hash"
  @empty_hash "0x0000000000000000000000000000000000000000000000000000000000000000"

  # 32-byte signature of the event WithdrawalProven(bytes32 indexed withdrawalHash, address indexed from, address indexed to)
  @withdrawal_proven_event "0x67a6208cfcc0801d50f6cbe764733f4fddf66ac0b04442061a8a8c0cb6b63f62"

  # 32-byte signature of the Blast chain event WithdrawalProven(bytes32 indexed withdrawalHash, address indexed from, address indexed to, uint256 requestId)
  @withdrawal_proven_event_blast "0x5d5446905f1f582d57d04ced5b1bed0f1a6847bcee57f7dd9d6f2ec12ab9ec2e"

  # 32-byte signature of the event WithdrawalFinalized(bytes32 indexed withdrawalHash, bool success)
  @withdrawal_finalized_event "0xdb5c7652857aa163daadd670e116628fb42e869d8ac4251ef8971d9e5727df1b"

  # 32-byte signature of the Blast chain event WithdrawalFinalized(bytes32 indexed withdrawalHash, uint256 indexed hintId, bool success)
  @withdrawal_finalized_event_blast "0x36d89e6190aa646d1a48286f8ad05e60a144483f42fd7e0ea08baba79343645b"

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
    {:ok, %{}, {:continue, :ok}}
  end

  @impl GenServer
  def handle_continue(:ok, _state) do
    Logger.metadata(fetcher: @fetcher_name)

    Optimism.init_continue(nil, __MODULE__)
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          contract_address: optimism_portal,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments,
          eth_get_logs_range_size: eth_get_logs_range_size
        } = state
      ) do
    # credo:disable-for-next-line
    time_before = Timex.now()

    chunks_number = ceil((end_block - start_block + 1) / eth_get_logs_range_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    last_written_block =
      chunk_range
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = start_block + eth_get_logs_range_size * current_chunk
        chunk_end = min(chunk_start + eth_get_logs_range_size - 1, end_block)

        if chunk_end >= chunk_start do
          Helper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, :L1)

          {:ok, result} =
            Helper.get_logs(
              chunk_start,
              chunk_end,
              optimism_portal,
              [
                [
                  @withdrawal_proven_event,
                  @withdrawal_proven_event_blast,
                  @withdrawal_finalized_event,
                  @withdrawal_finalized_event_blast
                ]
              ],
              json_rpc_named_arguments,
              0,
              Helper.infinite_retries_number()
            )

          withdrawal_events = prepare_events(result, json_rpc_named_arguments)

          {:ok, _} =
            Chain.import(%{
              optimism_withdrawal_events: %{params: withdrawal_events},
              timeout: :infinity
            })

          Helper.log_blocks_chunk_handling(
            chunk_start,
            chunk_end,
            start_block,
            end_block,
            "#{Enum.count(withdrawal_events)} WithdrawalProven/WithdrawalFinalized event(s)",
            :L1
          )
        end

        reorg_block = RollupReorgMonitorQueue.reorg_block_pop(__MODULE__)

        if !is_nil(reorg_block) && reorg_block > 0 do
          {deleted_count, _} = Repo.delete_all(from(we in WithdrawalEvent, where: we.l1_block_number >= ^reorg_block))

          log_deleted_rows_count(reorg_block, deleted_count)

          Optimism.set_last_block_hash(@empty_hash, @counter_type)

          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if chunk_end >= chunk_start do
            Optimism.set_last_block_hash_by_number(chunk_end, @counter_type, json_rpc_named_arguments)
          end

          {:cont, chunk_end}
        end
      end)

    new_start_block = last_written_block + 1
    new_end_block = Helper.fetch_latest_l1_block_number(json_rpc_named_arguments)

    delay =
      if new_end_block == last_written_block do
        # there is no new block, so wait for some time to let the chain issue the new block
        max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0)
      else
        0
      end

    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | start_block: new_start_block, end_block: new_end_block}}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp log_deleted_rows_count(reorg_block, count) do
    if count > 0 do
      Logger.warning(
        "As L1 reorg was detected, all rows with l1_block_number >= #{reorg_block} were removed from the op_withdrawal_events table. Number of removed rows: #{count}."
      )
    end
  end

  defp get_transaction_input_by_hash(blocks, transaction_hashes) do
    Enum.reduce(blocks, %{}, fn block, acc ->
      block
      |> Map.get("transactions", [])
      |> Enum.filter(fn transaction ->
        Enum.member?(transaction_hashes, transaction["hash"])
      end)
      |> Enum.map(fn transaction ->
        {transaction["hash"], transaction["input"]}
      end)
      |> Enum.into(%{})
      |> Map.merge(acc)
    end)
  end

  defp prepare_events(events, json_rpc_named_arguments) do
    blocks =
      events
      |> get_blocks_by_events(json_rpc_named_arguments, Helper.infinite_retries_number())

    transaction_hashes =
      events
      |> Enum.reduce([], fn event, acc ->
        if Enum.member?([@withdrawal_proven_event, @withdrawal_proven_event_blast], Enum.at(event["topics"], 0)) do
          [event["transactionHash"] | acc]
        else
          acc
        end
      end)

    input_by_hash = get_transaction_input_by_hash(blocks, transaction_hashes)

    timestamps =
      blocks
      |> Enum.reduce(%{}, fn block, acc ->
        block_number = quantity_to_integer(Map.get(block, "number"))
        {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
        Map.put(acc, block_number, timestamp)
      end)

    events
    |> Enum.map(fn event ->
      transaction_hash = event["transactionHash"]

      {l1_event_type, game_index} =
        if Enum.member?([@withdrawal_proven_event, @withdrawal_proven_event_blast], Enum.at(event["topics"], 0)) do
          game_index =
            input_by_hash
            |> Map.get(transaction_hash)
            |> input_to_game_index()

          {"WithdrawalProven", game_index}
        else
          {"WithdrawalFinalized", nil}
        end

      l1_block_number = quantity_to_integer(event["blockNumber"])

      %{
        withdrawal_hash: Enum.at(event["topics"], 1),
        l1_event_type: l1_event_type,
        l1_timestamp: Map.get(timestamps, l1_block_number),
        l1_transaction_hash: transaction_hash,
        l1_block_number: l1_block_number,
        game_index: game_index
      }
    end)
    |> Enum.reduce(%{}, fn e, acc ->
      key = {e.withdrawal_hash, e.l1_event_type}
      prev_game_index = Map.get(acc, key, %{game_index: 0}).game_index

      if prev_game_index < e.game_index or is_nil(prev_game_index) do
        Map.put(acc, key, e)
      else
        acc
      end
    end)
    |> Map.values()
  end

  @doc """
    Determines the last saved L1 block number, the last saved transaction hash, and the transaction info for L1 Withdrawal events.

    Used by the `Indexer.Fetcher.Optimism` module to start fetching from a correct block number
    after reorg has occurred.

    ## Parameters
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
                                  Used to get transaction info by its hash from the RPC node.

    ## Returns
    - A tuple `{last_block_number, last_transaction_hash, last_transaction}` where
      `last_block_number` is the last block number found in the corresponding table (0 if not found),
      `last_transaction_hash` is the last transaction hash found in the corresponding table (nil if not found),
      `last_transaction` is the transaction info got from the RPC (nil if not found).
    - A tuple `{:error, message}` in case the `eth_getTransactionByHash` RPC request failed.
  """
  @spec get_last_l1_item(EthereumJSONRPC.json_rpc_named_arguments()) ::
          {non_neg_integer(), binary() | nil, map() | nil} | {:error, any()}
  def get_last_l1_item(json_rpc_named_arguments) do
    Optimism.get_last_item(
      :L1,
      &WithdrawalEvent.last_event_l1_block_number_query/0,
      &WithdrawalEvent.remove_events_query/1,
      json_rpc_named_arguments,
      @counter_type
    )
  end

  @doc """
    Returns L1 RPC URL for this module.
  """
  @spec l1_rpc_url() :: binary() | nil
  def l1_rpc_url do
    Optimism.l1_rpc_url()
  end

  @doc """
    Determines if `Indexer.Fetcher.RollupL1ReorgMonitor` module must be up
    before this fetcher starts.

    ## Returns
    - `true` if the reorg monitor must be active, `false` otherwise.
  """
  @spec requires_l1_reorg_monitor?() :: boolean()
  def requires_l1_reorg_monitor? do
    Optimism.requires_l1_reorg_monitor?()
  end

  defp get_blocks_by_events(events, json_rpc_named_arguments, retries) do
    request =
      events
      |> Enum.reduce(%{}, fn event, acc ->
        Map.put(acc, event["blockNumber"], 0)
      end)
      |> Stream.map(fn {block_number, _} -> %{number: block_number} end)
      |> id_to_params()
      |> Blocks.requests(&ByNumber.request(&1, true, false))

    error_message = &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(request)}"

    case Helper.repeated_call(&json_rpc/2, [request, json_rpc_named_arguments], error_message, retries) do
      {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
      {:error, _} -> []
    end
  end

  defp input_to_game_index(input) do
    method_signature = String.slice(input, 0..9)

    if method_signature == "0x4870496f" do
      # the signature of `proveWithdrawalTransaction(tuple _transaction, uint256 _disputeGameIndex, tuple _outputRootProof, bytes[] _withdrawalProof)` method

      # to get (slice) `_disputeGameIndex` from the transaction input, we need to know its offset in the input string (represented as 0x...):
      # offset = 10 symbols of signature (incl. `0x` prefix) + 64 symbols (representing 32 bytes) of the `_transaction` tuple offset, totally is 74
      game_index_offset = String.length(method_signature) + 32 * 2
      game_index_length = 32 * 2

      game_index_range_start = game_index_offset
      game_index_range_end = game_index_range_start + game_index_length - 1

      {game_index, ""} =
        input
        |> String.slice(game_index_range_start..game_index_range_end)
        |> Integer.parse(16)

      game_index
    end
  end
end
