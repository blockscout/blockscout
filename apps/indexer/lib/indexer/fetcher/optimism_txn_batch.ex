defmodule Indexer.Fetcher.OptimismTxnBatch do
  @moduledoc """
  Fills op_transaction_batches DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [fetch_blocks_by_range: 2, json_rpc: 2, quantity_to_integer: 1]

  import Explorer.Helper, only: [parse_integer: 1]

  alias EthereumJSONRPC.Block.ByHash
  alias EthereumJSONRPC.Blocks
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.{Block, OptimismFrameSequence, OptimismTxnBatch}
  alias Indexer.Fetcher.Optimism
  alias Indexer.Helper

  @fetcher_name :optimism_txn_batches
  @future_frames_table_name :optimism_txn_batches_future_frames
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
    Logger.metadata(fetcher: @fetcher_name)

    json_rpc_named_arguments_l2 = args[:json_rpc_named_arguments]
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         {:reorg_monitor_started, true} <- {:reorg_monitor_started, !is_nil(Process.whereis(Indexer.Fetcher.Optimism))},
         optimism_l1_rpc = Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism][:optimism_l1_rpc],
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_l1_rpc)},
         {:batch_inbox_valid, true} <- {:batch_inbox_valid, Helper.is_address_correct?(env[:batch_inbox])},
         {:batch_submitter_valid, true} <- {:batch_submitter_valid, Helper.is_address_correct?(env[:batch_submitter])},
         start_block_l1 = parse_integer(env[:start_block_l1]),
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0,
         chunk_size = parse_integer(env[:blocks_chunk_size]),
         {:chunk_size_valid, true} <- {:chunk_size_valid, !is_nil(chunk_size) && chunk_size > 0},
         json_rpc_named_arguments = Optimism.json_rpc_named_arguments(optimism_l1_rpc),
         {last_l1_block_number, last_l1_transaction_hash, last_l1_tx} = get_last_l1_item(json_rpc_named_arguments),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_tx)},
         {:ok, block_check_interval, last_safe_block} <- Optimism.get_block_check_interval(json_rpc_named_arguments) do
      start_block = max(start_block_l1, last_l1_block_number)

      Subscriber.to(:optimism_reorg_block, :realtime)

      create_future_frames_table()

      Process.send(self(), :continue, [])

      {:ok,
       %{
         batch_inbox: String.downcase(env[:batch_inbox]),
         batch_submitter: String.downcase(env[:batch_submitter]),
         block_check_interval: block_check_interval,
         start_block: start_block,
         end_block: last_safe_block,
         chunk_size: chunk_size,
         incomplete_frame_sequence: empty_incomplete_frame_sequence(),
         last_channel_id: <<>>,
         current_channel_id: <<>>,
         json_rpc_named_arguments: json_rpc_named_arguments,
         json_rpc_named_arguments_l2: json_rpc_named_arguments_l2
       }}
    else
      {:start_block_l1_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        :ignore

      {:reorg_monitor_started, false} ->
        Logger.error("Cannot start this process as reorg monitor in Indexer.Fetcher.Optimism is not started.")
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

      {:chunk_size_valid, false} ->
        Logger.error("Invalid blocks chunk size value.")
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
  def handle_info(
        :continue,
        %{
          batch_inbox: batch_inbox,
          batch_submitter: batch_submitter,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          chunk_size: chunk_size,
          incomplete_frame_sequence: incomplete_frame_sequence,
          last_channel_id: last_channel_id,
          current_channel_id: current_channel_id,
          json_rpc_named_arguments: json_rpc_named_arguments,
          json_rpc_named_arguments_l2: json_rpc_named_arguments_l2
        } = state
      ) do
    time_before = Timex.now()

    chunks_number = ceil((end_block - start_block + 1) / chunk_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    {last_written_block, new_incomplete_frame_sequence, new_last_channel_id, new_current_channel_id} =
      chunk_range
      |> Enum.reduce_while(
        {start_block - 1, incomplete_frame_sequence, last_channel_id, current_channel_id},
        fn current_chunk, {_, incomplete_frame_sequence_acc, last_channel_id, current_channel_id} ->
          chunk_start = start_block + chunk_size * current_chunk
          chunk_end = min(chunk_start + chunk_size - 1, end_block)

          {new_incomplete_frame_sequence, new_last_channel_id, new_current_channel_id} =
            if chunk_end >= chunk_start do
              Optimism.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, "L1")

              {:ok, batches, sequences, new_incomplete_frame_sequence, new_last_channel_id, new_current_channel_id} =
                get_txn_batches(
                  Range.new(chunk_start, chunk_end),
                  batch_inbox,
                  batch_submitter,
                  incomplete_frame_sequence_acc,
                  {last_channel_id, current_channel_id},
                  json_rpc_named_arguments,
                  json_rpc_named_arguments_l2,
                  100_000_000
                )

              {batches, sequences} = remove_duplicates(batches, sequences)

              {:ok, _} =
                Chain.import(%{
                  optimism_frame_sequences: %{params: sequences},
                  optimism_txn_batches: %{params: batches},
                  timeout: :infinity
                })

              Optimism.log_blocks_chunk_handling(
                chunk_start,
                chunk_end,
                start_block,
                end_block,
                "#{Enum.count(batches)} batch(es)",
                "L1"
              )

              {new_incomplete_frame_sequence, new_last_channel_id, new_current_channel_id}
            else
              {incomplete_frame_sequence_acc, last_channel_id, current_channel_id}
            end

          reorg_block = Optimism.reorg_block_pop(@fetcher_name)

          if !is_nil(reorg_block) && reorg_block > 0 do
            {:halt,
             {if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end), nil, new_last_channel_id,
              new_current_channel_id}}
          else
            {:cont, {chunk_end, new_incomplete_frame_sequence, new_last_channel_id, new_current_channel_id}}
          end
        end
      )

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

    {:noreply,
     %{
       state
       | start_block: new_start_block,
         end_block: new_end_block,
         incomplete_frame_sequence: new_incomplete_frame_sequence,
         last_channel_id: new_last_channel_id,
         current_channel_id: new_current_channel_id
     }}
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

  defp empty_incomplete_frame_sequence(last_frame_number \\ -1) do
    %{bytes: <<>>, last_frame_number: last_frame_number, l1_transaction_hashes: []}
  end

  defp get_block_numbers_by_hashes(hashes, json_rpc_named_arguments_l2) do
    query =
      from(
        b in Block,
        select: {b.hash, b.number},
        where: b.hash in ^hashes
      )

    number_by_hash =
      query
      |> Repo.all(timeout: :infinity)
      |> Enum.reduce(%{}, fn {hash, number}, acc ->
        Map.put(acc, hash.bytes, number)
      end)

    requests =
      hashes
      |> Enum.filter(fn hash -> is_nil(Map.get(number_by_hash, hash)) end)
      |> Enum.with_index()
      |> Enum.map(fn {hash, id} ->
        ByHash.request(%{hash: "0x" <> Base.encode16(hash, case: :lower), id: id}, false)
      end)

    chunk_size = 50
    chunks_number = ceil(Enum.count(requests) / chunk_size)
    chunk_range = Range.new(0, chunks_number - 1, 1)

    chunk_range
    |> Enum.reduce([], fn current_chunk, acc ->
      {:ok, resp} =
        requests
        |> Enum.slice(chunk_size * current_chunk, chunk_size)
        |> json_rpc(json_rpc_named_arguments_l2)

      acc ++ resp
    end)
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
    l1_transaction_hashes =
      Repo.one(
        from(
          tb in OptimismTxnBatch,
          inner_join: fs in OptimismFrameSequence,
          on: fs.id == tb.frame_sequence_id,
          select: fs.l1_transaction_hashes,
          order_by: [desc: tb.l2_block_number],
          limit: 1
        )
      )

    last_l1_transaction_hash =
      if is_nil(l1_transaction_hashes) do
        nil
      else
        List.last(l1_transaction_hashes)
      end

    if is_nil(last_l1_transaction_hash) do
      {0, nil, nil}
    else
      {:ok, last_l1_tx} = Optimism.get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments)
      last_l1_block_number = quantity_to_integer(Map.get(last_l1_tx || %{}, "blockNumber", 0))
      {last_l1_block_number, last_l1_transaction_hash, last_l1_tx}
    end
  end

  defp get_txn_batches(
         block_range,
         batch_inbox,
         batch_submitter,
         incomplete_frame_sequence,
         {last_channel_id, current_channel_id},
         json_rpc_named_arguments,
         json_rpc_named_arguments_l2,
         retries_left
       ) do
    case fetch_blocks_by_range(block_range, json_rpc_named_arguments) do
      {:ok, %Blocks{transactions_params: transactions_params, blocks_params: blocks_params, errors: []}} ->
        from_block.._ = block_range
        transactions_filtered = txs_filter_sort(transactions_params, batch_submitter, batch_inbox)

        get_txn_batches_inner(
          transactions_filtered,
          blocks_params,
          from_block,
          batch_inbox,
          batch_submitter,
          incomplete_frame_sequence,
          {last_channel_id, current_channel_id},
          {json_rpc_named_arguments, json_rpc_named_arguments_l2}
        )

      {_, message_or_errors} ->
        message =
          case message_or_errors do
            %Blocks{errors: errors} -> errors
            msg -> msg
          end

        retries_left = retries_left - 1

        error_message = "Cannot fetch blocks #{inspect(block_range)}. Error(s): #{inspect(message)}"

        if retries_left <= 0 do
          Logger.error(error_message)
          {:error, message}
        else
          Logger.error("#{error_message} Retrying...")
          :timer.sleep(3000)

          get_txn_batches(
            block_range,
            batch_inbox,
            batch_submitter,
            incomplete_frame_sequence,
            {last_channel_id, current_channel_id},
            json_rpc_named_arguments,
            json_rpc_named_arguments_l2,
            retries_left
          )
        end
    end
  end

  defp get_txn_batches_inner(
         transactions_filtered,
         blocks_params,
         from_block,
         batch_inbox,
         batch_submitter,
         incomplete_frame_sequence,
         {last_channel_id, current_channel_id},
         {json_rpc_named_arguments, json_rpc_named_arguments_l2}
       ) do
    transactions_filtered
    |> Enum.reduce_while({:ok, [], [], incomplete_frame_sequence, last_channel_id, current_channel_id}, fn t,
                                                                                                           {_, batches,
                                                                                                            sequences,
                                                                                                            incomplete_frame_sequence_acc,
                                                                                                            last_channel_id,
                                                                                                            current_channel_id} ->
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
        {:cont, {:ok, [], [], empty_incomplete_frame_sequence(), last_channel_id, current_channel_id}}
      else
        frame_sequence = incomplete_frame_sequence_acc.bytes <> frame.data
        # credo:disable-for-next-line
        l1_transaction_hashes = incomplete_frame_sequence_acc.l1_transaction_hashes ++ [t.hash]
        last_frame_number = incomplete_frame_sequence_acc.last_frame_number

        with {:new_channel_id, true} <- {:new_channel_id, frame.channel_id != last_channel_id},
             {:frame_number_valid, true} <- {:frame_number_valid, frame.number == last_frame_number + 1},
             {:channel_id_valid, true} <-
               {:channel_id_valid, frame.channel_id == current_channel_id or current_channel_id == <<>>},
             {:frame_is_last, true} <- {:frame_is_last, frame.is_last},
             l1_timestamp = get_block_timestamp_by_number(t.block_number, blocks_params),
             {batches_parsed, seq} =
               get_new_batches_and_sequence(
                 frame_sequence,
                 sequences,
                 l1_transaction_hashes,
                 l1_timestamp,
                 json_rpc_named_arguments_l2,
                 after_reorg
               ),
             true <- batches_parsed != :error do
          {:cont,
           {:ok, batches ++ batches_parsed, [seq | sequences], empty_incomplete_frame_sequence(), frame.channel_id,
            <<>>}}
        else
          {:new_channel_id, false} ->
            # ignore duplicated transaction with the same channel_id
            {:cont, {:ok, batches, sequences, empty_incomplete_frame_sequence(), last_channel_id, current_channel_id}}

          {:frame_number_valid, false} ->
            l1_timestamp = get_block_timestamp_by_number(t.block_number, blocks_params)

            handle_invalid_frame_number(
              last_frame_number,
              frame,
              t,
              l1_timestamp,
              batches,
              sequences,
              {last_channel_id, current_channel_id},
              incomplete_frame_sequence_acc
            )

          {:channel_id_valid, false} ->
            # ignore invalid frame
            {:cont, {:ok, batches, sequences, incomplete_frame_sequence_acc, last_channel_id, current_channel_id}}

          {:frame_is_last, false} ->
            handle_not_last_valid_frame(
              batches,
              sequences,
              frame_sequence,
              frame,
              l1_transaction_hashes,
              last_channel_id,
              current_channel_id,
              json_rpc_named_arguments_l2
            )

          false ->
            {:halt,
             {:error,
              "Invalid RLP in frame sequence. Tx hash of the last frame: #{t.hash}. Compressed bytes of the sequence: 0x#{Base.encode16(frame_sequence, case: :lower)}"}}
        end
      end
    end)
  end

  # credo:disable-for-next-line /Complexity/
  defp handle_invalid_frame_number(
         last_frame_number,
         frame,
         tx,
         l1_timestamp,
         batches,
         sequences,
         {last_channel_id, current_channel_id},
         incomplete_frame_sequence
       ) do
    cond do
      frame.number == 0 ->
        # the new frame rewrites the previous frame sequence
        # todo: handle last frame (when frame.is_last == true)
        clear_future_frames()

        {:cont,
         {:ok, batches, sequences,
          %{bytes: frame.data, last_frame_number: frame.number, l1_transaction_hashes: [tx.hash]}, last_channel_id,
          frame.channel_id}}

      last_frame_number < 0 && frame.number > 0 ->
        # ignore duplicated frame with the number greater than 0
        {:cont, {:ok, batches, sequences, empty_incomplete_frame_sequence(), last_channel_id, current_channel_id}}

      frame.number > last_frame_number ->
        if frame.channel_id == current_channel_id do
          # temporarily save future frame to handle that later
          future_frame = %{frame: frame, l1_tx_hash: tx.hash, l1_timestamp: l1_timestamp}
          put_future_frame(current_channel_id, future_frame)
        end

        # ignore invalid frame
        {:cont, {:ok, batches, sequences, incomplete_frame_sequence, last_channel_id, current_channel_id}}

      frame.number < last_frame_number && frame.channel_id == current_channel_id &&
          :binary.match(incomplete_frame_sequence.bytes, frame.data) != :nomatch ->
        # ignore the frame (with the same channel id) which has already been concatenated before
        {:cont, {:ok, batches, sequences, incomplete_frame_sequence, last_channel_id, current_channel_id}}

      frame.number == last_frame_number && frame.channel_id == current_channel_id ->
        # ignore duplicated frame
        {:cont, {:ok, batches, sequences, incomplete_frame_sequence, last_channel_id, current_channel_id}}

      true ->
        {:halt,
         {:error,
          "Invalid frame sequence. Last frame number: #{last_frame_number}. Next frame number: #{frame.number}. Tx hash: #{tx.hash}."}}
    end
  end

  defp handle_not_last_valid_frame(
         batches,
         sequences,
         frame_sequence,
         frame,
         l1_transaction_hashes,
         last_channel_id,
         current_channel_id,
         json_rpc_named_arguments_l2
       ) do
    future_frames =
      current_channel_id
      |> get_future_frames(true)
      |> Enum.sort(fn f1, f2 -> f1.frame.number < f2.frame.number end)

    # %{frame: frame, l1_tx_hash: tx.hash, l1_timestamp: l1_timestamp}

    incomplete_frame_sequence_extended =
      future_frames
      |> Enum.reduce(
        %{bytes: frame_sequence, last_frame_number: frame.number, l1_transaction_hashes: []},
        fn future_frame, acc ->
          %{
            bytes: acc.bytes <> future_frame.frame.data,
            last_frame_number: future_frame.frame.number,
            l1_transaction_hashes: [future_frame.l1_tx_hash | acc.l1_transaction_hashes]
          }
        end
      )

    incomplete_frame_sequence =
      Map.put(
        incomplete_frame_sequence_extended,
        :l1_transaction_hashes,
        l1_transaction_hashes ++ Enum.reverse(incomplete_frame_sequence_extended.l1_transaction_hashes)
      )

    if not Enum.empty?(future_frames) and List.last(future_frames).frame.is_last do
      last_future_frame = List.last(future_frames)
      l1_timestamp = last_future_frame.l1_timestamp
      new_last_channel_id = last_future_frame.frame.channel_id

      {batches_parsed, seq} =
        get_new_batches_and_sequence(
          incomplete_frame_sequence.bytes,
          sequences,
          incomplete_frame_sequence.l1_transaction_hashes,
          l1_timestamp,
          json_rpc_named_arguments_l2,
          false
        )

      true = batches_parsed != :error

      {:cont,
       {:ok, batches ++ batches_parsed, [seq | sequences], empty_incomplete_frame_sequence(), new_last_channel_id, <<>>}}
    else
      new_current_channel_id =
        if frame.number == 0 do
          frame.channel_id
        else
          current_channel_id
        end

      {:cont, {:ok, batches, sequences, incomplete_frame_sequence, last_channel_id, new_current_channel_id}}
    end
  end

  defp get_new_batches_and_sequence(
         frame_sequence,
         sequences,
         l1_transaction_hashes,
         l1_timestamp,
         json_rpc_named_arguments_l2,
         after_reorg
       ) do
    frame_sequence_last = List.first(sequences)
    frame_sequence_id = next_frame_sequence_id(frame_sequence_last)

    batches_parsed =
      parse_frame_sequence(
        frame_sequence,
        frame_sequence_id,
        l1_timestamp,
        json_rpc_named_arguments_l2,
        after_reorg
      )

    seq = %{
      id: frame_sequence_id,
      l1_transaction_hashes: l1_transaction_hashes,
      l1_timestamp: l1_timestamp
    }

    {batches_parsed, seq}
  end

  defp input_to_frame("0x" <> input) do
    input_binary = Base.decode16!(input, case: :mixed)

    # the structure of the input is as follows:
    #
    # input = derivation_version ++ channel_id ++ frame_number ++ frame_data_length ++ frame_data ++ is_last
    #
    # derivation_version = uint8
    # channel_id         = bytes16
    # frame_number       = uint16
    # frame_data_length  = uint32
    # frame_data         = bytes
    # is_last            = bool (uint8)

    derivation_version_length = 1
    channel_id_length = 16
    frame_number_size = 2
    frame_data_length_size = 4
    is_last_size = 1

    # the first byte must be zero (so called Derivation Version)
    [0] = :binary.bin_to_list(binary_part(input_binary, 0, derivation_version_length))

    # channel id has 16 bytes
    channel_id = binary_part(input_binary, derivation_version_length, channel_id_length)

    # frame number consists of 2 bytes
    frame_number_offset = derivation_version_length + channel_id_length
    frame_number = :binary.decode_unsigned(binary_part(input_binary, frame_number_offset, frame_number_size))

    # frame data length consists of 4 bytes
    frame_data_length_offset = frame_number_offset + frame_number_size

    frame_data_length =
      :binary.decode_unsigned(binary_part(input_binary, frame_data_length_offset, frame_data_length_size))

    input_length_must_be =
      derivation_version_length + channel_id_length + frame_number_size + frame_data_length_size + frame_data_length +
        is_last_size

    input_length_current = byte_size(input_binary)

    if input_length_current == input_length_must_be do
      # frame data is a byte array of frame_data_length size
      frame_data_offset = frame_data_length_offset + frame_data_length_size
      frame_data = binary_part(input_binary, frame_data_offset, frame_data_length)

      # is_last is 1-byte item
      is_last_offset = frame_data_offset + frame_data_length
      is_last = :binary.decode_unsigned(binary_part(input_binary, is_last_offset, is_last_size)) > 0

      %{number: frame_number, data: frame_data, is_last: is_last, channel_id: channel_id}
    else
      # workaround to remove a leading extra byte
      # for example, the case for Base Goerli batch L1 transaction: https://goerli.etherscan.io/tx/0xa43fa9da683a6157a114e3175a625b5aed85d8c573aae226768c58a924a17be0
      input_to_frame("0x" <> Base.encode16(binary_part(input_binary, 1, input_length_current - 1)))
    end
  end

  defp log_deleted_rows_count(reorg_block, count) do
    if count > 0 do
      Logger.warning(
        "As L1 reorg was detected, all rows with l2_block_number >= #{reorg_block} were removed from the op_transaction_batches table. Number of removed rows: #{count}."
      )
    end
  end

  defp next_frame_sequence_id(last_known_sequence) when is_nil(last_known_sequence) do
    last_known_id =
      Repo.one(
        from(
          fs in OptimismFrameSequence,
          select: fs.id,
          order_by: [desc: fs.id],
          limit: 1
        )
      )

    if is_nil(last_known_id) do
      1
    else
      last_known_id + 1
    end
  end

  defp next_frame_sequence_id(last_known_sequence) do
    last_known_sequence.id + 1
  end

  defp parse_frame_sequence(
         bytes,
         id,
         l1_timestamp,
         json_rpc_named_arguments_l2,
         after_reorg
       ) do
    uncompressed_bytes = zlib_decompress(bytes)

    batches =
      Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), {uncompressed_bytes, []}, fn _i, {remainder, batch_acc} ->
        try do
          {decoded, new_remainder} = ExRLP.decode(remainder, stream: true)
          batch = ExRLP.decode(binary_part(decoded, 1, byte_size(decoded) - 1))

          batch = %{
            parent_hash: Enum.at(batch, 0),
            epoch_number: :binary.decode_unsigned(Enum.at(batch, 1)),
            frame_sequence_id: id,
            l1_timestamp: l1_timestamp
          }

          if byte_size(new_remainder) > 0 do
            {:cont, {new_remainder, [batch | batch_acc]}}
          else
            {:halt, [batch | batch_acc]}
          end
        rescue
          _ -> {:halt, :error}
        end
      end)

    if batches == :error do
      if after_reorg do
        []
      else
        :error
      end
    else
      batches = Enum.reverse(batches)

      numbers_by_hashes =
        batches
        |> Enum.map(fn batch -> batch.parent_hash end)
        |> get_block_numbers_by_hashes(json_rpc_named_arguments_l2)

      return =
        batches
        |> Stream.filter(&Map.has_key?(numbers_by_hashes, &1.parent_hash))
        |> Enum.map(fn batch ->
          number = Map.get(numbers_by_hashes, batch.parent_hash)

          batch
          |> Map.put(:l2_block_number, number + 1)
          |> Map.delete(:parent_hash)
        end)

      if after_reorg do
        # once we find the nearest full frame sequence after reorg, we first need to remove irrelevant items from op_transaction_batches table
        first_batch_l2_block_number = Enum.at(return, 0).l2_block_number

        frame_sequence_ids =
          Repo.all(
            from(
              tb in OptimismTxnBatch,
              select: tb.frame_sequence_id,
              where: tb.l2_block_number >= ^first_batch_l2_block_number
            ),
            timeout: :infinity
          )

        {deleted_count, _} =
          Repo.delete_all(from(tb in OptimismTxnBatch, where: tb.l2_block_number >= ^first_batch_l2_block_number))

        Repo.delete_all(from(fs in OptimismFrameSequence, where: fs.id in ^frame_sequence_ids))

        log_deleted_rows_count(first_batch_l2_block_number, deleted_count)
      end

      return
    end
  end

  defp remove_duplicates(batches, sequences) do
    unique_batches =
      batches
      |> Enum.sort(fn b1, b2 ->
        b1.l2_block_number < b2.l2_block_number or
          (b1.l2_block_number == b2.l2_block_number and b1.l1_timestamp < b2.l1_timestamp)
      end)
      |> Enum.reduce(%{}, fn b, acc ->
        Map.put(acc, b.l2_block_number, Map.delete(b, :l1_timestamp))
      end)
      |> Map.values()

    unique_sequences =
      if Enum.empty?(sequences) do
        []
      else
        sequences
        |> Enum.reverse()
        |> Enum.filter(fn seq ->
          Enum.any?(unique_batches, fn batch -> batch.frame_sequence_id == seq.id end)
        end)
      end

    {unique_batches, unique_sequences}
  end

  defp rewind_after_reorg(block_number, frame_number, batch_submitter, batch_inbox, json_rpc_named_arguments) do
    if frame_number == 0 do
      empty_incomplete_frame_sequence()
    else
      Enum.reduce_while(Stream.iterate(1, &(&1 + 1)), empty_incomplete_frame_sequence(frame_number), fn i,
                                                                                                        sequence_acc ->
        prev_block_number = block_number - i

        with {:ok, %Blocks{transactions_params: transactions, errors: []}} <-
               fetch_blocks_by_range(prev_block_number..prev_block_number, json_rpc_named_arguments),
             seq = txs_to_sequence(transactions, batch_submitter, batch_inbox, sequence_acc),
             true <- seq != :error,
             {false, seq} <- {seq.last_frame_number == 0, seq},
             true <- i < @reorg_rewind_limit do
          {:cont, seq}
        else
          {true, seq} -> {:halt, %{seq | last_frame_number: frame_number - 1}}
          _ -> {:halt, empty_incomplete_frame_sequence()}
        end
      end)
    end
  end

  defp txs_to_sequence(transactions, batch_submitter, batch_inbox, sequence_acc) do
    transactions
    |> txs_filter_sort(batch_submitter, batch_inbox, :desc)
    |> Enum.reduce_while(sequence_acc, fn t, acc ->
      frame = input_to_frame(t.input)

      if frame.number == acc.last_frame_number - 1 do
        {if(frame.number == 0, do: :halt, else: :cont),
         %{
           bytes: frame.data <> acc.bytes,
           last_frame_number: frame.number,
           l1_transaction_hashes: [t.hash | acc.l1_transaction_hashes]
         }}
      else
        {:halt, :error}
      end
    end)
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
      txs_filter_sort_fn(direction, t1, t2)
    end)
  end

  defp txs_filter_sort_fn(:asc, t1, t2) do
    txs_filter_sort_fn(:desc, t2, t1)
  end

  defp txs_filter_sort_fn(_direction, t1, t2) do
    cond do
      t1.block_number > t2.block_number ->
        true

      t1.block_number == t2.block_number ->
        t1_frame = input_to_frame(t1.input)
        t2_frame = input_to_frame(t2.input)

        (t1_frame.channel_id != t2_frame.channel_id and t1.transaction_index > t2.transaction_index) or
          (t1_frame.channel_id == t2_frame.channel_id and t1_frame.number > t2_frame.number)

      true ->
        false
    end
  end

  defp zlib_decompress(bytes) do
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

    uncompressed_bytes
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

  defp create_future_frames_table do
    if :ets.whereis(@future_frames_table_name) == :undefined do
      :ets.new(@future_frames_table_name, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end
  end

  defp clear_future_frames do
    :ets.delete_all_objects(@future_frames_table_name)
  end

  defp get_future_frames(channel_id, clear \\ false) do
    with info when info != :undefined <- :ets.info(@future_frames_table_name),
         [{_, value}] <- :ets.lookup(@future_frames_table_name, channel_id) do
      if clear do
        clear_future_frames()
      end

      value
    else
      _ -> []
    end
  end

  defp put_future_frame(channel_id, data) do
    list = [data | get_future_frames(channel_id)]
    :ets.insert(@future_frames_table_name, {channel_id, list})
  end
end
