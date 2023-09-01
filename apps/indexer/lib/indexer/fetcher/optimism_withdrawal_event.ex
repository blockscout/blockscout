defmodule Indexer.Fetcher.OptimismWithdrawalEvent do
  @moduledoc """
  Fills op_withdrawal_events DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.OptimismWithdrawalEvent
  alias Indexer.Fetcher.Optimism

  @fetcher_name :optimism_withdrawal_events

  # 32-byte signature of the event WithdrawalProven(bytes32 indexed withdrawalHash, address indexed from, address indexed to)
  @withdrawal_proven_event "0x67a6208cfcc0801d50f6cbe764733f4fddf66ac0b04442061a8a8c0cb6b63f62"

  # 32-byte signature of the event WithdrawalFinalized(bytes32 indexed withdrawalHash, bool success)
  @withdrawal_finalized_event "0xdb5c7652857aa163daadd670e116628fb42e869d8ac4251ef8971d9e5727df1b"

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

    env = Application.get_all_env(:indexer)[__MODULE__]
    optimism_l1_portal = Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism][:optimism_l1_portal]

    Optimism.init(env, optimism_l1_portal, __MODULE__)
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          contract_address: optimism_portal,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    # credo:disable-for-next-line
    time_before = Timex.now()

    chunks_number = ceil((end_block - start_block + 1) / Optimism.get_logs_range_size())
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    last_written_block =
      chunk_range
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = start_block + Optimism.get_logs_range_size() * current_chunk
        chunk_end = min(chunk_start + Optimism.get_logs_range_size() - 1, end_block)

        if chunk_end >= chunk_start do
          Optimism.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, "L1")

          {:ok, result} =
            Optimism.get_logs(
              chunk_start,
              chunk_end,
              optimism_portal,
              [@withdrawal_proven_event, @withdrawal_finalized_event],
              json_rpc_named_arguments,
              100_000_000
            )

          withdrawal_events = prepare_events(result, json_rpc_named_arguments)

          {:ok, _} =
            Chain.import(%{
              optimism_withdrawal_events: %{params: withdrawal_events},
              timeout: :infinity
            })

          Optimism.log_blocks_chunk_handling(
            chunk_start,
            chunk_end,
            start_block,
            end_block,
            "#{Enum.count(withdrawal_events)} WithdrawalProven/WithdrawalFinalized event(s)",
            "L1"
          )
        end

        reorg_block = Optimism.reorg_block_pop(@fetcher_name)

        if !is_nil(reorg_block) && reorg_block > 0 do
          {deleted_count, _} =
            Repo.delete_all(from(we in OptimismWithdrawalEvent, where: we.l1_block_number >= ^reorg_block))

          log_deleted_rows_count(reorg_block, deleted_count)

          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          {:cont, chunk_end}
        end
      end)

    new_start_block = last_written_block + 1
    {:ok, new_end_block} = Optimism.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

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
  def handle_info({:chain_event, :optimism_reorg_block, :realtime, block_number}, state) do
    Optimism.reorg_block_push(@fetcher_name, block_number)
    {:noreply, state}
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

  defp prepare_events(events, json_rpc_named_arguments) do
    timestamps =
      events
      |> get_blocks_by_events(json_rpc_named_arguments, 100_000_000)
      |> Enum.reduce(%{}, fn block, acc ->
        block_number = quantity_to_integer(Map.get(block, "number"))
        {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
        Map.put(acc, block_number, timestamp)
      end)

    Enum.map(events, fn event ->
      l1_event_type =
        if Enum.at(event["topics"], 0) == @withdrawal_proven_event do
          "WithdrawalProven"
        else
          "WithdrawalFinalized"
        end

      l1_block_number = quantity_to_integer(event["blockNumber"])

      %{
        withdrawal_hash: Enum.at(event["topics"], 1),
        l1_event_type: l1_event_type,
        l1_timestamp: Map.get(timestamps, l1_block_number),
        l1_transaction_hash: event["transactionHash"],
        l1_block_number: l1_block_number
      }
    end)
  end

  def get_last_l1_item do
    query =
      from(we in OptimismWithdrawalEvent,
        select: {we.l1_block_number, we.l1_transaction_hash},
        order_by: [desc: we.l1_timestamp],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  defp get_blocks_by_events(events, json_rpc_named_arguments, retries) do
    request =
      events
      |> Enum.reduce(%{}, fn event, acc ->
        Map.put(acc, event["blockNumber"], 0)
      end)
      |> Stream.map(fn {block_number, _} -> %{number: block_number} end)
      |> Stream.with_index()
      |> Enum.into(%{}, fn {params, id} -> {id, params} end)
      |> Blocks.requests(&ByNumber.request(&1, false, false))

    error_message = &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(request)}"

    case Optimism.repeated_request(request, error_message, json_rpc_named_arguments, retries) do
      {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
      {:error, _} -> []
    end
  end
end
