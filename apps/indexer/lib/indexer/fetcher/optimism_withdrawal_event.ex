defmodule Indexer.Fetcher.OptimismWithdrawalEvent do
  @moduledoc """
  Fills op_withdrawal_events DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [json_rpc: 2, quantity_to_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.OptimismWithdrawalEvent
  alias Indexer.BoundQueue
  alias Indexer.Fetcher.Optimism

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
    Logger.metadata(fetcher: :optimism_withdrawal_event)

    env = Application.get_all_env(:indexer)[__MODULE__]
    optimism_l1_portal = Application.get_env(:indexer, :optimism_l1_portal)

    Optimism.init(env, optimism_l1_portal, __MODULE__)
  end

  @impl GenServer
  def handle_continue(
        _,
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
      |> Enum.reduce_while(start_block - 1, fn current_chank, _ ->
        chunk_start = start_block + Optimism.get_logs_range_size() * current_chank
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

        reorg_block = reorg_block_pop()

        if !is_nil(reorg_block) && reorg_block > 0 do
          {deleted_count, _} =
            Repo.delete_all(from(we in OptimismWithdrawalEvent, where: we.l1_block_number >= ^reorg_block))

          if deleted_count > 0 do
            Logger.warning(
              "As L1 reorg was detected, all rows with l1_block_number >= #{reorg_block} were removed from the op_withdrawal_events table. Number of removed rows: #{deleted_count}."
            )
          end

          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          {:cont, chunk_end}
        end
      end)

    new_start_block = last_written_block + 1
    {:ok, new_end_block} = Optimism.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

    if new_end_block == last_written_block do
      # there is no new block, so wait for some time to let the chain issue the new block
      :timer.sleep(max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0))
    end

    {:noreply, %{state | start_block: new_start_block, end_block: new_end_block}, {:continue, nil}}
  end

  @impl GenServer
  def handle_info({ref, _result}, %{reorg_monitor_task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    {:noreply, %{state | reorg_monitor_task: nil}}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %{
          reorg_monitor_task: %Task{pid: pid, ref: ref},
          block_check_interval: block_check_interval,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    if reason === :normal do
      {:noreply, %{state | reorg_monitor_task: nil}}
    else
      Logger.error(fn -> "Reorgs monitor task exited due to #{inspect(reason)}. Rerunning..." end)

      task =
        Task.Supervisor.async_nolink(Indexer.Fetcher.OptimismWithdrawalEvent.TaskSupervisor, fn ->
          reorg_monitor(block_check_interval, json_rpc_named_arguments)
        end)

      {:noreply, %{state | reorg_monitor_task: task}}
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

  def reorg_monitor(block_check_interval, json_rpc_named_arguments) do
    Logger.metadata(fetcher: :optimism_withdrawal_event)

    # infinite loop
    Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), 0, fn _i, prev_latest ->
      {:ok, latest} = Optimism.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

      if latest < prev_latest do
        Logger.warning("Reorg detected: previous latest block ##{prev_latest}, current latest block ##{latest}.")
        reorg_block_push(latest)
      end

      :timer.sleep(block_check_interval)

      {:cont, latest}
    end)
  end

  defp reorg_block_pop do
    case BoundQueue.pop_front(reorg_queue_get()) do
      {:ok, {block_number, updated_queue}} ->
        :ets.insert(:op_withdrawal_events_reorgs, {:queue, updated_queue})
        block_number

      {:error, :empty} ->
        nil
    end
  end

  defp reorg_block_push(block_number) do
    {:ok, updated_queue} = BoundQueue.push_back(reorg_queue_get(), block_number)
    :ets.insert(:op_withdrawal_events_reorgs, {:queue, updated_queue})
  end

  defp reorg_queue_get do
    if :ets.whereis(:op_withdrawal_events_reorgs) == :undefined do
      :ets.new(:op_withdrawal_events_reorgs, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    with info when info != :undefined <- :ets.info(:op_withdrawal_events_reorgs),
         [{_, value}] <- :ets.lookup(:op_withdrawal_events_reorgs, :queue) do
      value
    else
      _ -> %BoundQueue{}
    end
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

  defp get_blocks_by_events(events, json_rpc_named_arguments, retries_left) do
    request =
      events
      |> Enum.reduce(%{}, fn event, acc ->
        Map.put(acc, event["blockNumber"], 0)
      end)
      |> Enum.map(fn {block_number, _} -> block_number end)
      |> Enum.with_index()
      |> Enum.map(fn {block_number, id} ->
        ByNumber.request(%{number: block_number, id: id}, false, false)
      end)

    case json_rpc(request, json_rpc_named_arguments) do
      {:ok, responses} ->
        Enum.map(responses, fn %{result: result} -> result end)

      {:error, message} ->
        retries_left = retries_left - 1

        error_message =
          "Cannot fetch blocks with batch request. Error: #{inspect(message)}. Request: #{inspect(request)}"

        if retries_left <= 0 do
          Logger.error(error_message)
          []
        else
          Logger.error("#{error_message} Retrying...")
          :timer.sleep(3000)
          get_blocks_by_events(events, json_rpc_named_arguments, retries_left)
        end
    end
  end
end
