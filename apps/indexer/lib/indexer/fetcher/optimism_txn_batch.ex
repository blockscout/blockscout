defmodule Indexer.Fetcher.OptimismTxnBatch do
  @moduledoc """
  Fills op_transaction_batches DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [fetch_blocks_by_range: 2, json_rpc: 2, quantity_to_integer: 1]

  alias EthereumJSONRPC.Blocks
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, OptimismTxnBatch}
  alias Indexer.BoundQueue
  alias Indexer.Fetcher.Optimism

  @block_check_interval_range_size 100
  @eth_get_block_range_size 4
  @reorg_rewind_limit 10

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
    Logger.metadata(fetcher: :optimism_txn_batch)

    json_rpc_named_arguments_l2 = args[:json_rpc_named_arguments]
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         optimism_rpc_l1 = Application.get_env(:indexer, :optimism_rpc_l1),
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_rpc_l1)},
         {:batch_inbox_valid, true} <- {:batch_inbox_valid, Optimism.is_address?(env[:batch_inbox])},
         {:batch_submitter_valid, true} <- {:batch_submitter_valid, Optimism.is_address?(env[:batch_submitter])},
         start_block_l1 = Optimism.parse_integer(env[:start_block_l1]),
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0,
         json_rpc_named_arguments = json_rpc_named_arguments(optimism_rpc_l1),
         {last_l1_block_number, last_l1_tx_hash, last_l1_tx} = get_last_l1_item(json_rpc_named_arguments),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_tx_hash) && is_nil(last_l1_tx)},
         {:ok, last_safe_block} <- Optimism.get_block_number_by_tag("safe", json_rpc_named_arguments),
         first_block = max(last_safe_block - @block_check_interval_range_size, 1),
         {:ok, first_block_timestamp} <- Optimism.get_block_timestamp_by_number(first_block, json_rpc_named_arguments),
         {:ok, last_safe_block_timestamp} <-
           Optimism.get_block_timestamp_by_number(last_safe_block, json_rpc_named_arguments) do
      block_check_interval =
        ceil((last_safe_block_timestamp - first_block_timestamp) / (last_safe_block - first_block) * 1000 / 2)

      Logger.info("Block check interval is calculated as #{block_check_interval} ms.")

      start_block = max(start_block_l1, last_l1_block_number)

      reorg_monitor_task =
        Task.Supervisor.async_nolink(Indexer.Fetcher.OptimismTxnBatch.TaskSupervisor, fn ->
          reorg_monitor(block_check_interval, json_rpc_named_arguments)
        end)

      {:ok,
       %{
         batch_inbox: String.downcase(env[:batch_inbox]),
         batch_submitter: String.downcase(env[:batch_submitter]),
         block_check_interval: block_check_interval,
         start_block: start_block,
         end_block: last_safe_block,
         reorg_monitor_task: reorg_monitor_task,
         incomplete_frame_sequence: empty_incomplete_frame_sequence(),
         json_rpc_named_arguments: json_rpc_named_arguments,
         json_rpc_named_arguments_l2: json_rpc_named_arguments_l2
       }, {:continue, nil}}
    else
      {:start_block_l1_undefined, true} ->
        # the process shoudln't start if the start block is not defined
        :ignore

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        :ignore

      {:batch_inbox_valid, false} ->
        Logger.error("Batch Inbox address is invalid or not defined.")
        :ignore

      {:batch_submitter_valid, false} ->
        Logger.error("Batch Submitter address is invalid or not defined.")
        :ignore

      {:start_block_l1_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and op_transaction_batches table.")
        :ignore

      {:error, error_data} ->
        Logger.error(
          "Cannot get last safe block or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        :ignore

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check op_transaction_batches table."
        )

        :ignore

      _ ->
        Logger.error("Batch Start Block is invalid or zero.")
        :ignore
    end
  end

  @impl GenServer
  def handle_continue(
        _,
        %{
          batch_inbox: batch_inbox,
          batch_submitter: batch_submitter,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          incomplete_frame_sequence: incomplete_frame_sequence,
          json_rpc_named_arguments: json_rpc_named_arguments,
          json_rpc_named_arguments_l2: json_rpc_named_arguments_l2
        } = state
      ) do
    # credo:disable-for-next-line
    time_before = Timex.now()

    chunks_number = ceil((end_block - start_block + 1) / @eth_get_block_range_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    {last_written_block, new_incomplete_frame_sequence} =
      chunk_range
      |> Enum.reduce_while({start_block - 1, incomplete_frame_sequence}, fn current_chank,
                                                                            {_, incomplete_frame_sequence_acc} ->
        chunk_start = start_block + @eth_get_block_range_size * current_chank
        chunk_end = min(chunk_start + @eth_get_block_range_size - 1, end_block)

        new_incomplete_frame_sequence =
          if chunk_end >= chunk_start do
            log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil)

            {:ok, batches, new_incomplete_frame_sequence} =
              get_txn_batches(
                chunk_start,
                chunk_end,
                batch_inbox,
                batch_submitter,
                incomplete_frame_sequence_acc,
                json_rpc_named_arguments,
                json_rpc_named_arguments_l2,
                100_000_000
              )

            batches = remove_duplicates(batches)

            if byte_size(new_incomplete_frame_sequence.bytes) > 0 do
              Logger.warn("new_incomplete_frame_sequence = #{inspect(new_incomplete_frame_sequence)}")
            end

            {:ok, _} =
              Chain.import(%{
                optimism_txn_batches: %{params: batches},
                timeout: :infinity
              })

            log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, Enum.count(batches))

            new_incomplete_frame_sequence
          else
            incomplete_frame_sequence_acc
          end

        reorg_block = reorg_block_pop()

        if !is_nil(reorg_block) && reorg_block > 0 do
          {:halt, {if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end), nil}}
        else
          {:cont, {chunk_end, new_incomplete_frame_sequence}}
        end
      end)

    new_start_block = last_written_block + 1
    {:ok, new_end_block} = Optimism.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

    if new_end_block == last_written_block do
      # there is no new block, so wait for some time to let the chain issue the new block
      :timer.sleep(max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0))
    end

    {:noreply,
     %{
       state
       | start_block: new_start_block,
         end_block: new_end_block,
         incomplete_frame_sequence: new_incomplete_frame_sequence
     }, {:continue, nil}}
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
        Task.Supervisor.async_nolink(Indexer.Fetcher.OptimismTxnBatch.TaskSupervisor, fn ->
          reorg_monitor(block_check_interval, json_rpc_named_arguments)
        end)

      {:noreply, %{state | reorg_monitor_task: task}}
    end
  end

  defp empty_incomplete_frame_sequence(last_frame_number \\ -1) do
    %{bytes: <<>>, last_frame_number: last_frame_number, l1_tx_hashes: []}
  end

  defp get_block_numbers_by_hashes(hashes, json_rpc_named_arguments_l2, l1_tx_hashes) do
    query =
      from(
        b in Block,
        select: {b.hash, b.number},
        where: b.hash in ^hashes
      )

    number_by_hash =
      query
      |> Repo.all()
      |> Enum.reduce(%{}, fn {hash, number}, acc ->
        Map.put(acc, hash.bytes, number)
      end)

    {:ok, responses} =
      hashes
      |> Enum.filter(fn hash -> is_nil(Map.get(number_by_hash, hash)) end)
      |> Enum.with_index()
      |> Enum.map(fn {hash, id} ->
        %{
          id: id,
          method: "eth_getBlockByHash",
          params: ["0x" <> Base.encode16(hash, case: :lower), false],
          jsonrpc: "2.0"
        }
      end)
      |> json_rpc(json_rpc_named_arguments_l2)

    responses
    |> Enum.map(fn %{result: result} -> result end)
    |> Enum.reduce(number_by_hash, fn block, acc ->
      if is_nil(block) do
        acc
      else
        block_number = quantity_to_integer(Map.get(block, "number"))
        "0x" <> hash = Map.get(block, "hash")
        {:ok, hash} = Base.decode16(hash, case: :lower)
        Map.put(acc, hash, block_number)
      end
    end)
  end

  defp get_block_timestamp_by_number(block_number, blocks_params) do
    block = Enum.find(blocks_params, %{timestamp: nil}, fn b -> b.number == block_number end)
    block.timestamp
  end

  defp get_last_l1_item(json_rpc_named_arguments) do
    l1_tx_hashes =
      Repo.one(
        from(
          tb in OptimismTxnBatch,
          select: tb.l1_tx_hashes,
          order_by: [desc: tb.l2_block_number],
          limit: 1
        )
      )

    last_l1_tx_hash =
      if is_nil(l1_tx_hashes) do
        nil
      else
        List.last(l1_tx_hashes)
      end

    if is_nil(last_l1_tx_hash) do
      {0, nil, nil}
    else
      {:ok, last_l1_tx} = Optimism.get_transaction_by_hash(last_l1_tx_hash, json_rpc_named_arguments)
      last_l1_block_number = quantity_to_integer(Map.get(last_l1_tx || %{}, "blockNumber", 0))
      {last_l1_block_number, last_l1_tx_hash, last_l1_tx}
    end
  end

  defp get_txn_batches(
         from_block,
         to_block,
         batch_inbox,
         batch_submitter,
         incomplete_frame_sequence,
         json_rpc_named_arguments,
         json_rpc_named_arguments_l2,
         retries_left
       ) do
    case fetch_blocks_by_range(from_block..to_block, json_rpc_named_arguments) do
      {:ok, %Blocks{transactions_params: transactions_params, blocks_params: blocks_params, errors: []}} ->
        transactions_params
        |> txs_filter_sort(batch_submitter, batch_inbox)
        |> Enum.reduce_while({:ok, [], incomplete_frame_sequence}, fn t, {_, batches, incomplete_frame_sequence_acc} ->
          after_reorg = is_nil(incomplete_frame_sequence_acc)

          frame = input_to_frame(t.input)

          {batches, incomplete_frame_sequence_acc} =
            if after_reorg do
              # there was a reorg, so try to rewind and concat bytes to build incomplete frame sequence if the `from_block` block starts with a frame with non-zero number.
              # if we cannot solve the puzzle, ignore the incomplete frame sequence and then find the nearest full one.
              {[], rewind_after_reorg(from_block, frame.number, batch_submitter, batch_inbox, json_rpc_named_arguments)}
            else
              {batches, incomplete_frame_sequence_acc}
            end

          if Enum.empty?(batches) and byte_size(incomplete_frame_sequence_acc.bytes) == 0 and frame.number > 0 do
            # if this is the first launch and the head of tx sequence, skip all transactions until frame.number is 0
            {:cont, {:ok, [], empty_incomplete_frame_sequence()}}
          else
            frame_sequence = incomplete_frame_sequence_acc.bytes <> frame.data
            l1_tx_hashes = incomplete_frame_sequence_acc.l1_tx_hashes ++ [t.hash]
            last_frame_number = incomplete_frame_sequence_acc.last_frame_number

            with {:frame_number_valid, true} <- {:frame_number_valid, frame.number == last_frame_number + 1},
                 {:frame_is_last, true} <- {:frame_is_last, frame.is_last},
                 l1_tx_timestamp = get_block_timestamp_by_number(t.block_number, blocks_params),
                 batches_parsed =
                   parse_frame_sequence(
                     frame_sequence,
                     l1_tx_hashes,
                     l1_tx_timestamp,
                     json_rpc_named_arguments_l2,
                     after_reorg
                   ),
                 true <- batches_parsed != :error do
              {:cont, {:ok, batches ++ batches_parsed, empty_incomplete_frame_sequence()}}
            else
              {:frame_number_valid, false} ->
                {:halt,
                 {:error,
                  "Invalid frame sequence. Last frame number: #{last_frame_number}. Next frame number: #{frame.number}. Tx hash: #{t.hash}."}}

              false ->
                {:halt,
                 {:error,
                  "Invalid RLP in frame sequence. Tx hash of the last frame: #{t.hash}. Compressed bytes of the sequence: 0x#{Base.encode16(frame_sequence, case: :lower)}"}}

              {:frame_is_last, false} ->
                {:cont,
                 {:ok, batches, %{bytes: frame_sequence, last_frame_number: frame.number, l1_tx_hashes: l1_tx_hashes}}}
            end
          end
        end)

      {_, message_or_errors} ->
        message =
          case message_or_errors do
            %Blocks{errors: errors} -> errors
            msg -> msg
          end

        retries_left = retries_left - 1

        error_message = "Cannot fetch blocks #{from_block}..#{to_block}. Error(s): #{inspect(message)}"

        if retries_left <= 0 do
          Logger.error(error_message)
          {:error, message}
        else
          Logger.error("#{error_message} Retrying...")
          :timer.sleep(3000)

          get_txn_batches(
            from_block,
            to_block,
            batch_inbox,
            batch_submitter,
            incomplete_frame_sequence,
            json_rpc_named_arguments,
            json_rpc_named_arguments_l2,
            retries_left
          )
        end
    end
  end

  defp input_to_frame("0x" <> input) do
    input_binary = Base.decode16!(input, case: :mixed)

    # the first byte must be zero (so called Derivation Version)
    [0] = :binary.bin_to_list(binary_slice(input_binary, 0, 1))

    frame_number = :binary.decode_unsigned(binary_slice(input_binary, 1 + 16, 2))
    frame_data_length = :binary.decode_unsigned(binary_slice(input_binary, 1 + 16 + 2, 4))
    frame_data = binary_slice(input_binary, 1 + 16 + 2 + 4, frame_data_length)
    is_last = :binary.decode_unsigned(binary_slice(input_binary, 1 + 16 + 2 + 4 + frame_data_length, 1)) > 0

    %{number: frame_number, data: frame_data, is_last: is_last}
  end

  defp json_rpc_named_arguments(optimism_rpc_l1) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        url: optimism_rpc_l1,
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end

  defp log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, batches_count) do
    {type, found} =
      if is_nil(batches_count) do
        {"Start", ""}
      else
        {"Finish", " Found #{batches_count} batch(es)."}
      end

    target_range =
      if chunk_start != start_block or chunk_end != end_block do
        progress =
          if is_nil(batches_count) do
            ""
          else
            percentage =
              (chunk_end - start_block + 1)
              |> Decimal.div(end_block - start_block + 1)
              |> Decimal.mult(100)
              |> Decimal.round(2)
              |> Decimal.to_string()

            " Progress: #{percentage}%"
          end

        " Target range: #{start_block}..#{end_block}.#{progress}"
      else
        ""
      end

    if chunk_start == chunk_end do
      Logger.info("#{type} handling L1 block ##{chunk_start}.#{found}#{target_range}")
    else
      Logger.info("#{type} handling L1 block range #{chunk_start}..#{chunk_end}.#{found}#{target_range}")
    end
  end

  defp parse_frame_sequence(bytes, l1_tx_hashes, l1_tx_timestamp, json_rpc_named_arguments_l2, after_reorg) do
    z = :zlib.open()
    :zlib.inflateInit(z)

    uncompressed_bytes =
      try do
        res = zlib_inflate(z, bytes)
        :zlib.inflateEnd(z)
        res
      rescue
        _ -> <<>>
      end

    :zlib.close(z)

    batches =
      Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), {uncompressed_bytes, []}, fn _i, {remainder, batch_acc} ->
        first_byte =
          case :binary.bin_to_list(binary_slice(remainder, 0, 1)) do
            [first_byte] -> first_byte
            _ -> nil
          end

        if Enum.member?(0xB8..0xBF, first_byte) do
          batch_size_length = first_byte - 0xB7

          batch_size =
            remainder
            |> binary_slice(1, batch_size_length)
            |> :binary.decode_unsigned()

          batch =
            remainder
            |> binary_slice(1 + batch_size_length + 1, batch_size - 1)
            |> ExRLP.decode()

          parent_hash = Enum.at(batch, 0)
          epoch_number = :binary.decode_unsigned(Enum.at(batch, 1))

          new_remainder_offset = 1 + batch_size_length + batch_size
          new_remainder_size = byte_size(remainder) - new_remainder_offset
          new_remainder = binary_slice(remainder, new_remainder_offset, new_remainder_size)

          new_batch_acc =
            batch_acc ++
              [
                %{
                  parent_hash: parent_hash,
                  epoch_number: epoch_number,
                  l1_tx_hashes: l1_tx_hashes,
                  l1_tx_timestamp: l1_tx_timestamp
                }
              ]

          if new_remainder_size > 0 do
            {:cont, {new_remainder, new_batch_acc}}
          else
            {:halt, new_batch_acc}
          end
        else
          {:halt, :error}
        end
      end)

    if batches == :error do
      if after_reorg do
        []
      else
        :error
      end
    else
      numbers_by_hashes =
        batches
        |> Enum.map(fn batch -> batch.parent_hash end)
        |> get_block_numbers_by_hashes(json_rpc_named_arguments_l2, l1_tx_hashes)

      return =
        batches
        |> Enum.reduce([], fn batch, acc ->
          case Map.fetch(numbers_by_hashes, batch.parent_hash) do
            {:ok, number} ->
              acc ++
                [
                  batch
                  |> Map.put(:l2_block_number, number + 1)
                  |> Map.delete(:parent_hash)
                ]

            _ ->
              acc
          end
        end)

      if after_reorg do
        # once we find the nearest full frame sequence after reorg, we first need to remove irrelevant items from op_transaction_batches table
        first_batch_l2_block_number = Enum.at(return, 0).l2_block_number

        {deleted_count, _} =
          Repo.delete_all(from(tb in OptimismTxnBatch, where: tb.l2_block_number >= ^first_batch_l2_block_number))

        if deleted_count > 0 do
          Logger.warning(
            "As L1 reorg was detected, all rows with l2_block_number >= #{first_batch_l2_block_number} were removed from the op_transaction_batches table. Number of removed rows: #{deleted_count}."
          )
        end
      end

      return
    end
  end

  defp remove_duplicates(batches) do
    batches
    |> Enum.sort(fn b1, b2 ->
      b1.l2_block_number < b2.l2_block_number or
        (b1.l2_block_number == b2.l2_block_number and b1.l1_tx_timestamp < b2.l1_tx_timestamp)
    end)
    |> Enum.reduce(%{}, fn b, acc ->
      Map.put(acc, b.l2_block_number, b)
    end)
    |> Map.values()
  end

  defp reorg_monitor(block_check_interval, json_rpc_named_arguments) do
    Logger.metadata(fetcher: :optimism_txn_batch)

    # infinite loop
    # credo:disable-for-next-line
    Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), 0, fn _i, prev_latest ->
      {:ok, latest} = Optimism.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

      if latest < prev_latest do
        Logger.warning("Reorg detected: previous latest block ##{prev_latest}, current latest block ##{latest}.")
        reorg_block_push(latest)
      end

      :timer.sleep(block_check_interval)

      {:cont, latest}
    end)

    :ok
  end

  defp reorg_block_pop do
    case BoundQueue.pop_front(reorg_queue_get()) do
      {:ok, {block_number, updated_queue}} ->
        :ets.insert(:op_txn_batches_reorgs, {:queue, updated_queue})
        block_number

      {:error, :empty} ->
        nil
    end
  end

  defp reorg_block_push(block_number) do
    {:ok, updated_queue} = BoundQueue.push_back(reorg_queue_get(), block_number)
    :ets.insert(:op_txn_batches_reorgs, {:queue, updated_queue})
  end

  defp reorg_queue_get do
    if :ets.whereis(:op_txn_batches_reorgs) == :undefined do
      :ets.new(:op_txn_batches_reorgs, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    with info when info != :undefined <- :ets.info(:op_txn_batches_reorgs),
         [{_, value}] <- :ets.lookup(:op_txn_batches_reorgs, :queue) do
      value
    else
      _ -> %BoundQueue{}
    end
  end

  defp rewind_after_reorg(block_number, frame_number, batch_submitter, batch_inbox, json_rpc_named_arguments) do
    if frame_number == 0 do
      empty_incomplete_frame_sequence()
    else
      Enum.reduce_while(Stream.iterate(1, &(&1 + 1)), empty_incomplete_frame_sequence(frame_number), fn i,
                                                                                                        sequence_acc ->
        prev_block_number = block_number - i

        case fetch_blocks_by_range(prev_block_number..prev_block_number, json_rpc_named_arguments) do
          {:ok, %Blocks{transactions_params: transactions, errors: []}} ->
            seq =
              transactions
              |> txs_filter_sort(batch_submitter, batch_inbox, :desc)
              |> Enum.reduce_while(sequence_acc, fn t, acc ->
                frame = input_to_frame(t.input)

                if frame.number == acc.last_frame_number - 1 do
                  {if(frame.number == 0, do: :halt, else: :cont),
                   %{
                     bytes: frame.data <> acc.bytes,
                     last_frame_number: frame.number,
                     l1_tx_hashes: [t.hash | acc.l1_tx_hashes]
                   }}
                else
                  {:halt, :error}
                end
              end)

            with true <- seq != :error,
                 false <- seq.last_frame_number == 0,
                 true <- i < @reorg_rewind_limit do
              {:cont, seq}
            else
              true -> {:halt, %{seq | last_frame_number: frame_number - 1}}
              false -> {:halt, empty_incomplete_frame_sequence()}
            end

          _ ->
            {:halt, empty_incomplete_frame_sequence()}
        end
      end)
    end
  end

  defp txs_filter_sort(transactions_params, batch_submitter, batch_inbox, direction \\ :asc) do
    transactions_params
    |> Enum.filter(fn t ->
      from_address_hash = Map.get(t, :from_address_hash)
      to_address_hash = Map.get(t, :to_address_hash)

      if is_nil(from_address_hash) or is_nil(to_address_hash) do
        false
      else
        String.downcase(from_address_hash) == batch_submitter and String.downcase(to_address_hash) == batch_inbox
      end
    end)
    |> Enum.sort(fn t1, t2 ->
      if direction == :asc do
        t1.block_number < t2.block_number or
          (t1.block_number == t2.block_number and t1.transaction_index < t2.transaction_index)
      else
        t1.block_number > t2.block_number or
          (t1.block_number == t2.block_number and t1.transaction_index > t2.transaction_index)
      end
    end)
  end

  defp zlib_inflate_handler(z, {:continue, [uncompressed_bytes]}, acc) do
    zlib_inflate(z, [], acc <> uncompressed_bytes)
  end

  defp zlib_inflate_handler(_z, {:finished, [uncompressed_bytes]}, acc) do
    acc <> uncompressed_bytes
  end

  defp zlib_inflate_handler(_z, {:finished, []}, acc) do
    acc
  end

  defp zlib_inflate(z, compressed_bytes, acc \\ <<>>) do
    result = :zlib.safeInflate(z, compressed_bytes)
    zlib_inflate_handler(z, result, acc)
  end
end
