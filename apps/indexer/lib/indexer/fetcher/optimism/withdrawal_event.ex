defmodule Indexer.Fetcher.Optimism.WithdrawalEvent do
  @moduledoc """
  Fills op_withdrawal_events DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

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

  # Prepares withdrawal events from `eth_getLogs` response to be imported to DB.
  #
  # ## Parameters
  # - `events`: The list of L1 withdrawal events from `eth_getLogs` response.
  # - `json_rpc_named_arguments`: JSON-RPC configuration containing transport options for L1.
  #
  # ## Returns
  # - A list of `WithdrawalEvent` maps.
  @spec prepare_events([map()], EthereumJSONRPC.json_rpc_named_arguments()) :: [WithdrawalEvent.to_import()]
  defp prepare_events(events, json_rpc_named_arguments) do
    blocks =
      events
      |> Helper.get_blocks_by_events(json_rpc_named_arguments, Helper.infinite_retries_number(), true)

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

      {l1_event_type, game_index, game_address_hash} =
        if Enum.member?([@withdrawal_proven_event, @withdrawal_proven_event_blast], Enum.at(event["topics"], 0)) do
          {game_index, game_address_hash} =
            input_by_hash
            |> Map.get(transaction_hash)
            |> input_to_game_index_or_address_hash()

          {:WithdrawalProven, game_index, game_address_hash}
        else
          {:WithdrawalFinalized, nil, nil}
        end

      l1_block_number = quantity_to_integer(event["blockNumber"])

      %{
        withdrawal_hash: Enum.at(event["topics"], 1),
        l1_event_type: l1_event_type,
        l1_timestamp: Map.get(timestamps, l1_block_number),
        l1_transaction_hash: transaction_hash,
        l1_block_number: l1_block_number,
        game_index: game_index,
        game_address_hash: game_address_hash
      }
    end)
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

  # Parses input of the prove L1 transaction and retrieves dispute game index or contract address hash
  # (depending on whether Super Roots are active) from that.
  #
  # ## Parameters
  # - `input`: The L1 transaction input in form of `0x` string.
  #
  # ## Returns
  # - `{game_index, game_address_hash}` tuple where one of the elements is not `nil`, but another one is `nil` (and vice versa).
  #   Both elements can be `nil` if the input cannot be parsed (or has unsupported format).
  @spec input_to_game_index_or_address_hash(String.t()) :: {non_neg_integer() | nil, String.t() | nil}
  defp input_to_game_index_or_address_hash(input) do
    method_signature = String.slice(input, 0..9)

    case method_signature do
      "0x4870496f" ->
        # the signature of `proveWithdrawalTransaction(tuple _transaction, uint256 _disputeGameIndex, tuple _outputRootProof, bytes[] _withdrawalProof)` method
        {game_index, ""} =
          method_signature
          |> slice_game_index_or_address_hash(input)
          |> Integer.parse(16)

        {game_index, nil}

      "0x8c90dd65" ->
        # the signature of `proveWithdrawalTransaction(tuple _transaction, address _disputeGameProxy, uint256 _outputRootIndex, tuple _superRootProof, tuple _outputRootProof, bytes[] _withdrawalProof)` method
        game_address_hash =
          method_signature
          |> slice_game_index_or_address_hash(input)
          |> String.trim_leading("000000000000000000000000")
          |> String.pad_leading(42, "0x")

        {nil, game_address_hash}

      _ ->
        {nil, nil}
    end
  end

  # Gets (slices) the dispute game index or its address hash from the transaction input represented as `0x` string.
  #
  # The input is calldata for either
  #   `proveWithdrawalTransaction(tuple _transaction, uint256 _disputeGameIndex, tuple _outputRootProof, bytes[] _withdrawalProof)`
  #   or
  #   `proveWithdrawalTransaction(tuple _transaction, address _disputeGameProxy, uint256 _outputRootIndex, tuple _superRootProof, tuple _outputRootProof, bytes[] _withdrawalProof)`
  #   method.
  #
  # ## Parameters
  # - `method_signature`: The method signature string (including `0x` prefix).
  # - `input`: The input string (including `0x` prefix).
  #
  # ## Returns
  # - The slice of the input containing dispute game index or address hash.
  @spec slice_game_index_or_address_hash(String.t(), String.t()) :: String.t()
  defp slice_game_index_or_address_hash(method_signature, input) do
    # to get (slice) the index or address from the transaction input, we need to know its offset in the input string (represented as 0x...):
    # offset = signature_length (10 symbols including `0x`) + 64 symbols (representing 32 bytes) of the `_transaction` tuple offset, totally is 74
    offset = String.length(method_signature) + 32 * 2
    length = 32 * 2

    range_start = offset
    range_end = range_start + length - 1

    String.slice(input, range_start..range_end)
  end
end
