defmodule Indexer.Fetcher.OptimismWithdrawal do
  @moduledoc """
  Fills op_withdrawals DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC,
    only: [request: 1, json_rpc: 2, fetch_block_number_by_tag: 2, integer_to_quantity: 1, quantity_to_integer: 1]

  alias ABI.TypeDecoder
  alias EthereumJSONRPC.Block.ByNumber
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Data, OptimismWithdrawal}

  @eth_get_logs_range_size 1000

  # 32-byte signature of the event MessagePassed(uint256 indexed nonce, address indexed sender, address indexed target, uint256 value, uint256 gasLimit, bytes data, bytes32 withdrawalHash)
  @message_passed_event "0x02a52367d10742d8032712c1bb8e0144ff1ec5ffda1ed7d70bb05a2744955054"

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
    Logger.metadata(fetcher: :optimism_withdrawals)

    json_rpc_named_arguments = args[:json_rpc_named_arguments]
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_l2_undefined, false} <- {:start_block_l2_undefined, is_nil(env[:start_block_l2])},
         {:message_passer_valid, true} <- {:message_passer_valid, is_address?(env[:message_passer])},
         start_block_l2 <- parse_integer(env[:start_block_l2]),
         false <- is_nil(start_block_l2),
         true <- start_block_l2 > 0,
         {last_l2_block_number, last_l2_tx_hash} <- get_last_l2_item(),
         {:start_block_l2_valid, true} <-
           {:start_block_l2_valid, start_block_l2 <= last_l2_block_number || last_l2_block_number == 0},
         {:ok, last_l2_tx} <- get_transaction_by_hash(last_l2_tx_hash, json_rpc_named_arguments),
         {:l2_tx_not_found, false} <- {:l2_tx_not_found, !is_nil(last_l2_tx_hash) && is_nil(last_l2_tx)} do
      start_block = max(start_block_l2, last_l2_block_number)

      :ignore
      # {:ok,
      #  %{
      #    message_passer: env[:message_passer],
      #    start_block: start_block,
      #    end_block: end_block,
      #    json_rpc_named_arguments: json_rpc_named_arguments
      #  }, {:continue, nil}}
    else
      {:start_block_l2_undefined, true} ->
        # the process shoudln't start if the start block is not defined
        :ignore

      {:message_passer_valid, false} ->
        Logger.error("L2ToL1MessagePasser contract address is invalid or not defined.")
        :ignore

      {:start_block_l2_valid, false} ->
        Logger.error("Invalid L2 Start Block value. Please, check the value and op_withdrawals table.")
        :ignore

      {:error, error_data} ->
        Logger.error("Cannot get last L2 transaction from RPC by its hash due to RPC error: #{inspect(error_data)}")

        :ignore

      {:l2_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L2 transaction from RPC by its hash. Probably, there was a reorg on L2 chain. Please, check op_withdrawals table."
        )

        :ignore

      _ ->
        Logger.error("Withdrawals L2 Start Block is invalid or zero.")
        :ignore
    end
  end

  def remove(starting_block) do
    Repo.delete_all(from(w in OptimismWithdrawal, where: w.l2_block_number >= ^starting_block))
  end

  # @impl GenServer
  # def handle_continue(
  #       _,
  #       %{
  #         output_oracle: output_oracle,
  #         block_check_interval: block_check_interval,
  #         start_block: start_block,
  #         end_block: end_block,
  #         json_rpc_named_arguments: json_rpc_named_arguments
  #       } = state
  #     ) do
  #   time_before = Timex.now()

  #   chunks_number = ceil((end_block - start_block + 1) / @eth_get_logs_range_size)
  #   chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

  #   last_written_block =
  #     chunk_range
  #     |> Enum.reduce_while(start_block - 1, fn current_chank, _ ->
  #       chunk_start = start_block + @eth_get_logs_range_size * current_chank
  #       chunk_end = min(chunk_start + @eth_get_logs_range_size - 1, end_block)

  #       if chunk_end >= chunk_start do
  #         log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil)

  #         {:ok, result} =
  #           get_logs(
  #             chunk_start,
  #             chunk_end,
  #             output_oracle,
  #             @output_proposed_event,
  #             json_rpc_named_arguments,
  #             100_000_000
  #           )

  #         output_roots = events_to_output_roots(result)

  #         {:ok, _} =
  #           Chain.import(%{
  #             output_roots: %{params: output_roots},
  #             timeout: :infinity
  #           })

  #         log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, Enum.count(output_roots))
  #       end

  #       reorg_block = reorg_block_pop()

  #       if !is_nil(reorg_block) && reorg_block > 0 do
  #         {deleted_count, _} = Repo.delete_all(from(r in OptimismOutputRoot, where: r.l1_block_number >= ^reorg_block))

  #         if deleted_count > 0 do
  #           Logger.warning(
  #             "As L1 reorg was detected, all rows with l1_block_number >= #{reorg_block} were removed from the op_output_roots table. Number of removed rows: #{deleted_count}."
  #           )
  #         end

  #         {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
  #       else
  #         {:cont, chunk_end}
  #       end
  #     end)

  #   new_start_block = last_written_block + 1
  #   {:ok, new_end_block} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

  #   if new_end_block == last_written_block do
  #     # there is no new block, so wait for some time to let the chain issue the new block
  #     :timer.sleep(max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0))
  #   end

  #   {:noreply, %{state | start_block: new_start_block, end_block: new_end_block}, {:continue, nil}}
  # end

  # @impl GenServer
  # def handle_info({ref, _result}, %{reorg_monitor_task: %Task{ref: ref}} = state) do
  #   Process.demonitor(ref, [:flush])
  #   {:noreply, %{state | reorg_monitor_task: nil}}
  # end

  # def handle_info(
  #       {:DOWN, ref, :process, pid, reason},
  #       %{
  #         reorg_monitor_task: %Task{pid: pid, ref: ref},
  #         block_check_interval: block_check_interval,
  #         json_rpc_named_arguments: json_rpc_named_arguments
  #       } = state
  #     ) do
  #   if reason === :normal do
  #     {:noreply, %{state | reorg_monitor_task: nil}}
  #   else
  #     Logger.error(fn -> "Reorgs monitor task exited due to #{inspect(reason)}. Rerunning..." end)

  #     task =
  #       Task.Supervisor.async_nolink(Indexer.Fetcher.OptimismOutputRoot.TaskSupervisor, fn ->
  #         reorg_monitor(block_check_interval, json_rpc_named_arguments)
  #       end)

  #     {:noreply, %{state | reorg_monitor_task: task}}
  #   end
  # end

  # defp events_to_output_roots(events) do
  #   Enum.map(events, fn event ->
  #     [l1_timestamp] = decode_data(event["data"], [{:uint, 256}])
  #     {:ok, l1_timestamp} = DateTime.from_unix(l1_timestamp)

  #     %{
  #       l2_output_index: quantity_to_integer(Enum.at(event["topics"], 2)),
  #       l2_block_number: quantity_to_integer(Enum.at(event["topics"], 3)),
  #       l1_tx_hash: event["transactionHash"],
  #       l1_timestamp: l1_timestamp,
  #       l1_block_number: quantity_to_integer(event["blockNumber"]),
  #       output_root: Enum.at(event["topics"], 1)
  #     }
  #   end)
  # end

  defp get_last_l2_item do
    query =
      from(w in OptimismWithdrawal,
        select: {w.l2_block_number, w.l2_tx_hash},
        order_by: [desc: w.msg_nonce],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  defp get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left \\ 3)

  defp get_transaction_by_hash(hash, _json_rpc_named_arguments, _retries_left) when is_nil(hash), do: {:ok, nil}

  defp get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left) do
    req =
      request(%{
        id: 0,
        method: "eth_getTransactionByHash",
        params: [hash]
      })

    case json_rpc(req, json_rpc_named_arguments) do
      {:ok, tx} ->
        {:ok, tx}

      {:error, message} ->
        retries_left = retries_left - 1

        if retries_left <= 0 do
          {:error, message}
        else
          :timer.sleep(3000)
          get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left)
        end
    end
  end

  # defp get_block_number_by_tag(tag, json_rpc_named_arguments, retries_left \\ 3) do
  #   case fetch_block_number_by_tag(tag, json_rpc_named_arguments) do
  #     {:ok, block_number} ->
  #       {:ok, block_number}

  #     {:error, message} ->
  #       retries_left = retries_left - 1

  #       error_message = "Cannot fetch #{tag} block number. Error: #{inspect(message)}"

  #       if retries_left <= 0 do
  #         Logger.error(error_message)
  #         {:error, message}
  #       else
  #         Logger.error("#{error_message} Retrying...")
  #         :timer.sleep(3000)
  #         get_block_number_by_tag(tag, json_rpc_named_arguments, retries_left)
  #       end
  #   end
  # end

  # defp get_block_timestamp_by_number(number, json_rpc_named_arguments, retries_left \\ 3) do
  #   result =
  #     %{id: 0, number: number}
  #     |> ByNumber.request(false)
  #     |> json_rpc(json_rpc_named_arguments)

  #   return =
  #     with {:ok, block} <- result,
  #          false <- is_nil(block),
  #          timestamp <- Map.get(block, "timestamp"),
  #          false <- is_nil(timestamp) do
  #       {:ok, quantity_to_integer(timestamp)}
  #     else
  #       {:error, message} ->
  #         {:error, message}

  #       true ->
  #         {:error, "RPC returned nil."}
  #     end

  #   case return do
  #     {:ok, timestamp} ->
  #       {:ok, timestamp}

  #     {:error, message} ->
  #       retries_left = retries_left - 1

  #       error_message = "Cannot fetch block ##{number} or its timestamp. Error: #{inspect(message)}"

  #       if retries_left <= 0 do
  #         Logger.error(error_message)
  #         {:error, message}
  #       else
  #         Logger.error("#{error_message} Retrying...")
  #         :timer.sleep(3000)
  #         get_block_timestamp_by_number(number, json_rpc_named_arguments, retries_left)
  #       end
  #   end
  # end

  # defp get_logs(from_block, to_block, address, topic0, json_rpc_named_arguments, retries_left) do
  #   req =
  #     request(%{
  #       id: 0,
  #       method: "eth_getLogs",
  #       params: [
  #         %{
  #           :fromBlock => integer_to_quantity(from_block),
  #           :toBlock => integer_to_quantity(to_block),
  #           :address => address,
  #           :topics => [topic0]
  #         }
  #       ]
  #     })

  #   case json_rpc(req, json_rpc_named_arguments) do
  #     {:ok, results} ->
  #       {:ok, results}

  #     {:error, message} ->
  #       retries_left = retries_left - 1

  #       error_message = "Cannot fetch logs for the block range #{from_block}..#{to_block}. Error: #{inspect(message)}"

  #       if retries_left <= 0 do
  #         Logger.error(error_message)
  #         {:error, message}
  #       else
  #         Logger.error("#{error_message} Retrying...")
  #         :timer.sleep(3000)
  #         get_logs(from_block, to_block, address, topic0, json_rpc_named_arguments, retries_left)
  #       end
  #   end
  # end

  # defp log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, output_roots_count) do
  #   {type, found} =
  #     if is_nil(output_roots_count) do
  #       {"Start", ""}
  #     else
  #       {"Finish", " Found #{output_roots_count} OutputProposed event(s)."}
  #     end

  #   if chunk_start == chunk_end do
  #     Logger.info("#{type} handling L1 block ##{chunk_start}.#{found}")
  #   else
  #     target_range =
  #       if chunk_start != start_block or chunk_end != end_block do
  #         progress =
  #           if is_nil(output_roots_count) do
  #             ""
  #           else
  #             percentage =
  #               (chunk_end - start_block + 1)
  #               |> Decimal.div(end_block - start_block + 1)
  #               |> Decimal.mult(100)
  #               |> Decimal.round(2)
  #               |> Decimal.to_string()

  #             " Progress: #{percentage}%"
  #           end

  #         " Target range: #{start_block}..#{end_block}.#{progress}"
  #       else
  #         ""
  #       end

  #     Logger.info("#{type} handling L1 block range #{chunk_start}..#{chunk_end}.#{found}#{target_range}")
  #   end
  # end

  defp parse_integer(integer_string) when is_binary(integer_string) do
    case Integer.parse(integer_string) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp parse_integer(_integer_string), do: nil

  defp is_address?(value) when is_binary(value) do
    String.match?(value, ~r/^0x[[:xdigit:]]{40}$/i)
  end

  defp is_address?(_value) do
    false
  end

  # defp decode_data("0x", types) do
  #   for _ <- types, do: nil
  # end

  # defp decode_data("0x" <> encoded_data, types) do
  #   encoded_data
  #   |> Base.decode16!(case: :mixed)
  #   |> TypeDecoder.decode_raw(types)
  # end

  # defp decode_data(%Data{} = data, types) do
  #   data
  #   |> Data.to_string()
  #   |> decode_data(types)
  # end
end
