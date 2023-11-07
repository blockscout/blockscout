defmodule Indexer.Fetcher.Shibarium.L1 do
  @moduledoc """
  Fills shibarium_bridge DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [
    fetch_block_number_by_tag: 2,
    json_rpc: 2,
    quantity_to_integer: 1,
    request: 1
  ]

  import Explorer.Helper, only: [parse_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias Indexer.{BoundQueue, Helper}
  alias Explorer.Chain.Shibarium.Bridge
  # alias EthereumJSONRPC.Blocks
  alias Explorer.Repo
  # alias Explorer.Chain.OptimismWithdrawalEvent
  # alias Indexer.Fetcher.Optimism

  @fetcher_name :shibarium_bridge_l1
  @block_check_interval_range_size 100

  # 32-byte signature of the event WithdrawalProven(bytes32 indexed withdrawalHash, address indexed from, address indexed to)
  # @withdrawal_proven_event "0x67a6208cfcc0801d50f6cbe764733f4fddf66ac0b04442061a8a8c0cb6b63f62"

  # 32-byte signature of the event WithdrawalFinalized(bytes32 indexed withdrawalHash, bool success)
  # @withdrawal_finalized_event "0xdb5c7652857aa163daadd670e116628fb42e869d8ac4251ef8971d9e5727df1b"

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

    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_undefined, false} <- {:start_block_undefined, is_nil(env[:start_block])},
         rpc = env[:rpc],
         {:rpc_undefined, false} <- {:rpc_undefined, is_nil(rpc)},
         {:deposit_manager_address_is_valid, true} <- {:deposit_manager_address_is_valid, Helper.is_address_correct?(env[:deposit_manager_proxy])},
         {:ether_predicate_address_is_valid, true} <- {:ether_predicate_address_is_valid, Helper.is_address_correct?(env[:ether_predicate_proxy])},
         {:erc20_predicate_address_is_valid, true} <- {:erc20_predicate_address_is_valid, Helper.is_address_correct?(env[:erc20_predicate_proxy])},
         {:withdraw_manager_address_is_valid, true} <- {:withdraw_manager_address_is_valid, Helper.is_address_correct?(env[:withdraw_manager_proxy])},
         start_block = parse_integer(env[:start_block]),
         false <- is_nil(start_block),
         true <- start_block > 0,
         {last_l1_block_number, last_l1_transaction_hash} <- get_last_l1_item(),
         {:start_block_valid, true} <-
           {:start_block_valid, start_block <= last_l1_block_number || last_l1_block_number == 0},
         json_rpc_named_arguments = json_rpc_named_arguments(rpc),
         {:ok, last_l1_tx} <- get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments),
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_tx)},
         {:ok, block_check_interval, latest_block} <- get_block_check_interval(json_rpc_named_arguments) do
      Process.send(self(), :reorg_monitor, [])
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         deposit_manager_proxy: env[:deposit_manager_proxy],
         ether_predicate_proxy: env[:ether_predicate_proxy],
         erc20_predicate_proxy: env[:erc20_predicate_proxy],
         withdraw_manager_proxy: env[:withdraw_manager_proxy],
         block_check_interval: block_check_interval,
         start_block: max(start_block, last_l1_block_number),
         end_block: latest_block,
         json_rpc_named_arguments: json_rpc_named_arguments,
         reorg_monitor_prev_latest: 0
       }}
    else
      {:start_block_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, %{}}

      {:rpc_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, %{}}

      {:deposit_manager_address_is_valid, false} ->
        Logger.error("DepositManagerProxy contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:ether_predicate_address_is_valid, false} ->
        Logger.error("EtherPredicateProxy contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:erc20_predicate_address_is_valid, false} ->
        Logger.error("ERC20PredicateProxy contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:withdraw_manager_address_is_valid, false} ->
        Logger.error("WithdrawManagerProxy contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:start_block_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and shibarium_bridge table.")
        {:stop, :normal, %{}}

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash, latest block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )
        {:stop, :normal, %{}}

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check shibarium_bridge table."
        )
        {:stop, :normal, %{}}

      _ ->
        Logger.error("L1 Start Block is invalid or zero.")
        {:stop, :normal, %{}}
    end
  end

  @impl GenServer
  def handle_info(
        :reorg_monitor,
        %{
          block_check_interval: block_check_interval,
          json_rpc_named_arguments: json_rpc_named_arguments,
          reorg_monitor_prev_latest: prev_latest
        } = state
      ) do
    {:ok, latest} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

    if latest < prev_latest do
      Logger.warning("Reorg detected: previous latest block ##{prev_latest}, current latest block ##{latest}.")
      reorg_block_push(latest)
    end

    Process.send_after(self(), :reorg_monitor, block_check_interval)

    {:noreply, %{state | reorg_monitor_prev_latest: latest}}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp get_block_check_interval(json_rpc_named_arguments) do
    with {:ok, latest_block} <- get_block_number_by_tag("latest", json_rpc_named_arguments),
         first_block = max(latest_block - @block_check_interval_range_size, 1),
         {:ok, first_block_timestamp} <- get_block_timestamp_by_number(first_block, json_rpc_named_arguments),
         {:ok, last_safe_block_timestamp} <- get_block_timestamp_by_number(latest_block, json_rpc_named_arguments) do
      block_check_interval =
        ceil((last_safe_block_timestamp - first_block_timestamp) / (latest_block - first_block) * 1000 / 2)

      Logger.info("Block check interval is calculated as #{block_check_interval} ms.")
      {:ok, block_check_interval, latest_block}
    else
      {:error, error} ->
        {:error, "Failed to calculate block check interval due to #{inspect(error)}"}
    end
  end

  defp get_block_number_by_tag(tag, json_rpc_named_arguments, retries \\ 3) do
    error_message = &"Cannot fetch #{tag} block number. Error: #{inspect(&1)}"
    repeated_call(&fetch_block_number_by_tag/2, [tag, json_rpc_named_arguments], error_message, retries)
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

  defp get_block_timestamp_by_number(number, json_rpc_named_arguments, retries \\ 3) do
    func = &get_block_timestamp_by_number_inner/2
    args = [number, json_rpc_named_arguments]
    error_message = &"Cannot fetch block ##{number} or its timestamp. Error: #{inspect(&1)}"
    repeated_call(func, args, error_message, retries)
  end

  defp get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left \\ 3)

  defp get_transaction_by_hash(hash, _json_rpc_named_arguments, _retries_left) when is_nil(hash), do: {:ok, nil}

  defp get_transaction_by_hash(hash, json_rpc_named_arguments, retries) do
    req =
      request(%{
        id: 0,
        method: "eth_getTransactionByHash",
        params: [hash]
      })

    error_message = &"eth_getTransactionByHash failed. Error: #{inspect(&1)}"

    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  defp json_rpc_named_arguments(rpc_url) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        url: rpc_url,
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end

  defp reorg_block_push(block_number) do
    table_name = reorg_table_name(@fetcher_name)
    {:ok, updated_queue} = BoundQueue.push_back(reorg_queue_get(table_name), block_number)
    :ets.insert(table_name, {:queue, updated_queue})
  end

  defp reorg_queue_get(table_name) do
    if :ets.whereis(table_name) == :undefined do
      :ets.new(table_name, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    with info when info != :undefined <- :ets.info(table_name),
         [{_, value}] <- :ets.lookup(table_name, :queue) do
      value
    else
      _ -> %BoundQueue{}
    end
  end

  defp reorg_table_name(fetcher_name) do
    :"#{fetcher_name}#{:_reorgs}"
  end

  defp repeated_call(func, args, error_message, retries_left) do
    case apply(func, args) do
      {:ok, _} = res ->
        res

      {:error, message} = err ->
        retries_left = retries_left - 1

        if retries_left <= 0 do
          Logger.error(error_message.(message))
          err
        else
          Logger.error("#{error_message.(message)} Retrying...")
          :timer.sleep(3000)
          repeated_call(func, args, error_message, retries_left)
        end
    end
  end

  # def init_continue(env, contract_address, caller) do
  #   {contract_name, table_name, start_block_note} =
  #     if caller == Indexer.Fetcher.OptimismWithdrawalEvent do
  #       {"Optimism Portal", "op_withdrawal_events", "Withdrawals L1"}
  #     else
  #       {"Output Oracle", "op_output_roots", "Output Roots"}
  #     end

  #   with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
  #        optimism_l1_rpc = Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism][:optimism_l1_rpc],
  #        {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_l1_rpc)},
  #        {:contract_is_valid, true} <- {:contract_is_valid, Helper.is_address_correct?(contract_address)},
  #        start_block_l1 = parse_integer(env[:start_block_l1]),
  #        false <- is_nil(start_block_l1),
  #        true <- start_block_l1 > 0,
  #        {last_l1_block_number, last_l1_transaction_hash} <- caller.get_last_l1_item(),
  #        {:start_block_l1_valid, true} <-
  #          {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
  #        json_rpc_named_arguments = json_rpc_named_arguments(optimism_l1_rpc),
  #        {:ok, last_l1_tx} <- get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments),
  #        {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_tx)},
  #        {:ok, block_check_interval, last_safe_block} <- get_block_check_interval(json_rpc_named_arguments) do
  #     start_block = max(start_block_l1, last_l1_block_number)

  #     Subscriber.to(:optimism_reorg_block, :realtime)

  #     Process.send(self(), :continue, [])

  #     {:noreply,
  #      %{
  #        contract_address: contract_address,
  #        block_check_interval: block_check_interval,
  #        start_block: start_block,
  #        end_block: last_safe_block,
  #        json_rpc_named_arguments: json_rpc_named_arguments
  #      }}
  #   else
  #     {:start_block_l1_undefined, true} ->
  #       # the process shouldn't start if the start block is not defined
  #       {:stop, :normal, %{}}

  #     {:rpc_l1_undefined, true} ->
  #       Logger.error("L1 RPC URL is not defined.")
  #       {:stop, :normal, %{}}

  #     {:contract_is_valid, false} ->
  #       Logger.error("#{contract_name} contract address is invalid or not defined.")
  #       {:stop, :normal, %{}}

  #     {:start_block_l1_valid, false} ->
  #       Logger.error("Invalid L1 Start Block value. Please, check the value and #{table_name} table.")
  #       {:stop, :normal, %{}}

  #     {:error, error_data} ->
  #       Logger.error(
  #         "Cannot get last L1 transaction from RPC by its hash, last safe block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
  #       )

  #       {:stop, :normal, %{}}

  #     {:l1_tx_not_found, true} ->
  #       Logger.error(
  #         "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check #{table_name} table."
  #       )

  #       {:stop, :normal, %{}}

  #     _ ->
  #       Logger.error("#{start_block_note} Start Block is invalid or zero.")
  #       {:stop, :normal, %{}}
  #   end
  # end

  # @impl GenServer
  # def handle_info(
  #       :continue,
  #       %{
  #         contract_address: optimism_portal,
  #         block_check_interval: block_check_interval,
  #         start_block: start_block,
  #         end_block: end_block,
  #         json_rpc_named_arguments: json_rpc_named_arguments
  #       } = state
  #     ) do
  #   time_before = Timex.now()

  #   chunks_number = ceil((end_block - start_block + 1) / Optimism.get_logs_range_size())
  #   chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

  #   last_written_block =
  #     chunk_range
  #     |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
  #       chunk_start = start_block + Optimism.get_logs_range_size() * current_chunk
  #       chunk_end = min(chunk_start + Optimism.get_logs_range_size() - 1, end_block)

  #       if chunk_end >= chunk_start do
  #         Optimism.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, "L1")

  #         {:ok, result} =
  #           Optimism.get_logs(
  #             chunk_start,
  #             chunk_end,
  #             optimism_portal,
  #             [@withdrawal_proven_event, @withdrawal_finalized_event],
  #             json_rpc_named_arguments,
  #             100_000_000
  #           )

  #         withdrawal_events = prepare_events(result, json_rpc_named_arguments)

  #         {:ok, _} =
  #           Chain.import(%{
  #             optimism_withdrawal_events: %{params: withdrawal_events},
  #             timeout: :infinity
  #           })

  #         Optimism.log_blocks_chunk_handling(
  #           chunk_start,
  #           chunk_end,
  #           start_block,
  #           end_block,
  #           "#{Enum.count(withdrawal_events)} WithdrawalProven/WithdrawalFinalized event(s)",
  #           "L1"
  #         )
  #       end

  #       reorg_block = Optimism.reorg_block_pop(@fetcher_name)

  #       if !is_nil(reorg_block) && reorg_block > 0 do
  #         {deleted_count, _} =
  #           Repo.delete_all(from(we in OptimismWithdrawalEvent, where: we.l1_block_number >= ^reorg_block))

  #         log_deleted_rows_count(reorg_block, deleted_count)

  #         {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
  #       else
  #         {:cont, chunk_end}
  #       end
  #     end)

  #   new_start_block = last_written_block + 1
  #   {:ok, new_end_block} = Optimism.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

  #   delay =
  #     if new_end_block == last_written_block do
  #       # there is no new block, so wait for some time to let the chain issue the new block
  #       max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0)
  #     else
  #       0
  #     end

  #   Process.send_after(self(), :continue, delay)

  #   {:noreply, %{state | start_block: new_start_block, end_block: new_end_block}}
  # end

  # @impl GenServer
  # def handle_info({:chain_event, :optimism_reorg_block, :realtime, block_number}, state) do
  #   Optimism.reorg_block_push(@fetcher_name, block_number)
  #   {:noreply, state}
  # end

  # defp log_deleted_rows_count(reorg_block, count) do
  #   if count > 0 do
  #     Logger.warning(
  #       "As L1 reorg was detected, all rows with l1_block_number >= #{reorg_block} were removed from the op_withdrawal_events table. Number of removed rows: #{count}."
  #     )
  #   end
  # end

  # defp prepare_events(events, json_rpc_named_arguments) do
  #   timestamps =
  #     events
  #     |> get_blocks_by_events(json_rpc_named_arguments, 100_000_000)
  #     |> Enum.reduce(%{}, fn block, acc ->
  #       block_number = quantity_to_integer(Map.get(block, "number"))
  #       {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
  #       Map.put(acc, block_number, timestamp)
  #     end)

  #   Enum.map(events, fn event ->
  #     l1_event_type =
  #       if Enum.at(event["topics"], 0) == @withdrawal_proven_event do
  #         "WithdrawalProven"
  #       else
  #         "WithdrawalFinalized"
  #       end

  #     l1_block_number = quantity_to_integer(event["blockNumber"])

  #     %{
  #       withdrawal_hash: Enum.at(event["topics"], 1),
  #       l1_event_type: l1_event_type,
  #       l1_timestamp: Map.get(timestamps, l1_block_number),
  #       l1_transaction_hash: event["transactionHash"],
  #       l1_block_number: l1_block_number
  #     }
  #   end)
  # end

  defp get_last_l1_item do
    query =
      from(sb in Bridge,
        select: {sb.l1_block_number, sb.l1_transaction_hash},
        order_by: [desc: sb.l1_block_number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  # defp get_blocks_by_events(events, json_rpc_named_arguments, retries) do
  #   request =
  #     events
  #     |> Enum.reduce(%{}, fn event, acc ->
  #       Map.put(acc, event["blockNumber"], 0)
  #     end)
  #     |> Stream.map(fn {block_number, _} -> %{number: block_number} end)
  #     |> Stream.with_index()
  #     |> Enum.into(%{}, fn {params, id} -> {id, params} end)
  #     |> Blocks.requests(&ByNumber.request(&1, false, false))

  #   error_message = &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(request)}"

  #   case Optimism.repeated_request(request, error_message, json_rpc_named_arguments, retries) do
  #     {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
  #     {:error, _} -> []
  #   end
  # end
end
