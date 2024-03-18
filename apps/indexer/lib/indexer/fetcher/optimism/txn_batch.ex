defmodule Indexer.Fetcher.Optimism.TxnBatch do
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
  alias Explorer.Chain.Beacon.Blob, as: BeaconBlob
  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Chain.Optimism.FrameSequence
  alias Explorer.Chain.Optimism.TxnBatch, as: OptimismTxnBatch
  alias HTTPoison.Response
  alias Indexer.Fetcher.Beacon.Blob
  alias Indexer.Fetcher.Beacon.Client, as: BeaconClient
  alias Indexer.Fetcher.{Optimism, RollupL1ReorgMonitor}
  alias Indexer.Helper
  alias Varint.LEB128

  @fetcher_name :optimism_txn_batches

  # Optimism chain block time is a constant (2 seconds)
  @op_chain_block_time 2

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
    {:ok, %{json_rpc_named_arguments_l2: args[:json_rpc_named_arguments]}, {:continue, nil}}
  end

  @impl GenServer
  def handle_continue(_, state) do
    Logger.metadata(fetcher: @fetcher_name)
    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    Process.send_after(self(), :init_with_delay, 2000)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:init_with_delay, %{json_rpc_named_arguments_l2: json_rpc_named_arguments_l2} = state) do
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         {:genesis_block_l2_invalid, false} <-
           {:genesis_block_l2_invalid, is_nil(env[:genesis_block_l2]) or env[:genesis_block_l2] < 0},
         {:reorg_monitor_started, true} <- {:reorg_monitor_started, !is_nil(Process.whereis(RollupL1ReorgMonitor))},
         optimism_l1_rpc = Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism][:optimism_l1_rpc],
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_l1_rpc)},
         {:blobs_api_url_undefined, false} <- {:blobs_api_url_undefined, is_nil(env[:blobs_api_url])},
         {:batch_inbox_valid, true} <- {:batch_inbox_valid, Helper.address_correct?(env[:batch_inbox])},
         {:batch_submitter_valid, true} <- {:batch_submitter_valid, Helper.address_correct?(env[:batch_submitter])},
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

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         batch_inbox: String.downcase(env[:batch_inbox]),
         batch_submitter: String.downcase(env[:batch_submitter]),
         blobs_api_url: String.trim_trailing(env[:blobs_api_url], "/"),
         block_check_interval: block_check_interval,
         start_block: start_block,
         end_block: last_safe_block,
         chunk_size: chunk_size,
         incomplete_channels: %{},
         genesis_block_l2: env[:genesis_block_l2],
         json_rpc_named_arguments: json_rpc_named_arguments,
         json_rpc_named_arguments_l2: json_rpc_named_arguments_l2
       }}
    else
      {:start_block_l1_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, state}

      {:genesis_block_l2_invalid, true} ->
        Logger.error("L2 genesis block number is undefined or invalid.")
        {:stop, :normal, state}

      {:reorg_monitor_started, false} ->
        Logger.error(
          "Cannot start this process as reorg monitor in Indexer.Fetcher.RollupL1ReorgMonitor is not started."
        )

        {:stop, :normal, state}

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, state}

      {:blobs_api_url_undefined, true} ->
        Logger.error("L1 Blockscout Blobs API URL is not defined.")
        {:stop, :normal, state}

      {:batch_inbox_valid, false} ->
        Logger.error("Batch Inbox address is invalid or not defined.")
        {:stop, :normal, state}

      {:batch_submitter_valid, false} ->
        Logger.error("Batch Submitter address is invalid or not defined.")
        {:stop, :normal, state}

      {:start_block_l1_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and op_transaction_batches table.")
        {:stop, :normal, state}

      {:chunk_size_valid, false} ->
        Logger.error("Invalid blocks chunk size value.")
        {:stop, :normal, state}

      {:error, error_data} ->
        Logger.error("Cannot get block timestamp by its number due to RPC error: #{inspect(error_data)}")

        {:stop, :normal, state}

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check op_transaction_batches table."
        )

        {:stop, :normal, state}

      _ ->
        Logger.error("Batch Start Block is invalid or zero.")
        {:stop, :normal, state}
    end
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          batch_inbox: batch_inbox,
          batch_submitter: batch_submitter,
          blobs_api_url: blobs_api_url,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          chunk_size: chunk_size,
          incomplete_channels: incomplete_channels,
          genesis_block_l2: genesis_block_l2,
          json_rpc_named_arguments: json_rpc_named_arguments,
          json_rpc_named_arguments_l2: json_rpc_named_arguments_l2
        } = state
      ) do
    time_before = Timex.now()

    chunks_number = ceil((end_block - start_block + 1) / chunk_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    {last_written_block, new_incomplete_channels} =
      chunk_range
      |> Enum.reduce_while({start_block - 1, incomplete_channels}, fn current_chunk, {_, incomplete_channels_acc} ->
        chunk_start = start_block + chunk_size * current_chunk
        chunk_end = min(chunk_start + chunk_size - 1, end_block)

        new_incomplete_channels =
          if chunk_end >= chunk_start do
            Helper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, :L1)

            {:ok, new_incomplete_channels, batches, sequences} =
              get_txn_batches(
                Range.new(chunk_start, chunk_end),
                batch_inbox,
                batch_submitter,
                genesis_block_l2,
                incomplete_channels_acc,
                {json_rpc_named_arguments, json_rpc_named_arguments_l2},
                blobs_api_url,
                Helper.infinite_retries_number()
              )

            {batches, sequences} = remove_duplicates(batches, sequences)

            {:ok, _} =
              Chain.import(%{
                optimism_frame_sequences: %{params: sequences},
                optimism_txn_batches: %{params: batches},
                timeout: :infinity
              })

            Helper.log_blocks_chunk_handling(
              chunk_start,
              chunk_end,
              start_block,
              end_block,
              "#{Enum.count(sequences)} batch(es) containing #{Enum.count(batches)} block(s).",
              :L1
            )

            new_incomplete_channels
          else
            incomplete_channels_acc
          end

        reorg_block = RollupL1ReorgMonitor.reorg_block_pop(__MODULE__)

        if !is_nil(reorg_block) && reorg_block > 0 do
          new_incomplete_channels = handle_l1_reorg(reorg_block, new_incomplete_channels)
          {:halt, {if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end), new_incomplete_channels}}
        else
          {:cont, {chunk_end, new_incomplete_channels}}
        end
      end)

    new_start_block = last_written_block + 1

    {:ok, new_end_block} =
      Optimism.get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number())

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
         incomplete_channels: new_incomplete_channels
     }}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp get_block_numbers_by_hashes([], _json_rpc_named_arguments_l2) do
    %{}
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
          inner_join: fs in FrameSequence,
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
         genesis_block_l2,
         incomplete_channels,
         {json_rpc_named_arguments, json_rpc_named_arguments_l2},
         blobs_api_url,
         retries_left
       ) do
    case fetch_blocks_by_range(block_range, json_rpc_named_arguments) do
      {:ok, %Blocks{transactions_params: transactions_params, blocks_params: blocks_params, errors: []}} ->
        transactions_params
        |> txs_filter(batch_submitter, batch_inbox)
        |> get_txn_batches_inner(
          blocks_params,
          genesis_block_l2,
          incomplete_channels,
          json_rpc_named_arguments_l2,
          blobs_api_url
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
            genesis_block_l2,
            incomplete_channels,
            {json_rpc_named_arguments, json_rpc_named_arguments_l2},
            blobs_api_url,
            retries_left
          )
        end
    end
  end

  defp blobs_to_inputs(transaction_hash, blob_versioned_hashes, block_timestamp, blobs_api_url) do
    blob_versioned_hashes
    |> Enum.reduce([], fn blob_hash, acc ->
      with {:ok, response} <- http_get_request(blobs_api_url <> "/" <> blob_hash),
           blob_data = Map.get(response, "blob_data"),
           false <- is_nil(blob_data) do
        # read the data from Blockscout API
        decoded =
          blob_data
          |> String.trim_leading("0x")
          |> Base.decode16!(case: :lower)
          |> OptimismTxnBatch.decode_eip4844_blob()

        if is_nil(decoded) do
          Logger.warning("Cannot decode the blob #{blob_hash} taken from the Blockscout Blobs API.")
          acc
        else
          Logger.info(
            "The input for transaction #{transaction_hash} is taken from the Blockscout Blobs API. Blob hash: #{blob_hash}"
          )

          [decoded | acc]
        end
      else
        _ ->
          # read the data from the fallback source (beacon node)

          beacon_config =
            :indexer
            |> Application.get_env(Blob)
            |> Keyword.take([:reference_slot, :reference_timestamp, :slot_duration])
            |> Enum.into(%{})

          try do
            {:ok, fetched_blobs} =
              block_timestamp
              |> DateTime.to_unix()
              |> Blob.timestamp_to_slot(beacon_config)
              |> BeaconClient.get_blob_sidecars()

            blobs = Map.get(fetched_blobs, "data", [])

            if Enum.empty?(blobs) do
              raise "Empty data"
            end

            decoded_blob_data =
              blobs
              |> Enum.find(fn b ->
                b
                |> Map.get("kzg_commitment", "0x")
                |> String.trim_leading("0x")
                |> Base.decode16!(case: :lower)
                |> BeaconBlob.hash()
                |> Hash.to_string()
                |> Kernel.==(blob_hash)
              end)
              |> Map.get("blob")
              |> String.trim_leading("0x")
              |> Base.decode16!(case: :lower)
              |> OptimismTxnBatch.decode_eip4844_blob()

            if is_nil(decoded_blob_data) do
              raise "Invalid blob"
            else
              Logger.info(
                "The input for transaction #{transaction_hash} is taken from the Beacon Node. Blob hash: #{blob_hash}"
              )

              [decoded_blob_data | acc]
            end
          rescue
            reason ->
              Logger.warning(
                "Cannot decode the blob #{blob_hash} taken from the Beacon Node. Reason: #{inspect(reason)}"
              )

              acc
          end
      end
    end)
    |> Enum.reverse()
  end

  defp get_txn_batches_inner(
         transactions_filtered,
         blocks_params,
         genesis_block_l2,
         incomplete_channels,
         json_rpc_named_arguments_l2,
         blobs_api_url
       ) do
    transactions_filtered
    |> Enum.reduce({:ok, incomplete_channels, [], []}, fn tx,
                                                          {_, incomplete_channels_acc, batches_acc, sequences_acc} ->
      inputs =
        if tx.type == 3 do
          # this is EIP-4844 transaction, so we get the inputs from the blobs
          block_timestamp = get_block_timestamp_by_number(tx.block_number, blocks_params)
          blobs_to_inputs(tx.hash, tx.blob_versioned_hashes, block_timestamp, blobs_api_url)
        else
          [tx.input]
        end

      Enum.reduce(inputs, {:ok, incomplete_channels_acc, batches_acc, sequences_acc}, fn input,
                                                                                         {_,
                                                                                          new_incomplete_channels_acc,
                                                                                          new_batches_acc,
                                                                                          new_sequences_acc} ->
        handle_input(
          input,
          tx,
          blocks_params,
          new_incomplete_channels_acc,
          new_batches_acc,
          new_sequences_acc,
          genesis_block_l2,
          json_rpc_named_arguments_l2
        )
      end)
    end)
  end

  defp handle_input(
         input,
         tx,
         blocks_params,
         incomplete_channels_acc,
         batches_acc,
         sequences_acc,
         genesis_block_l2,
         json_rpc_named_arguments_l2
       ) do
    frame = input_to_frame(input)

    channel = Map.get(incomplete_channels_acc, frame.channel_id, %{frames: %{}})

    channel_frames =
      Map.put(channel.frames, frame.number, %{
        data: frame.data,
        is_last: frame.is_last,
        block_number: tx.block_number,
        tx_hash: tx.hash
      })

    l1_timestamp =
      if frame.is_last do
        get_block_timestamp_by_number(tx.block_number, blocks_params)
      else
        Map.get(channel, :l1_timestamp)
      end

    channel_updated =
      channel
      |> Map.put_new(:id, frame.channel_id)
      |> Map.put(:frames, channel_frames)
      |> Map.put(:timestamp, DateTime.utc_now())
      |> Map.put(:l1_timestamp, l1_timestamp)

    if channel_complete?(channel_updated) do
      handle_channel(
        channel_updated,
        incomplete_channels_acc,
        batches_acc,
        sequences_acc,
        genesis_block_l2,
        json_rpc_named_arguments_l2
      )
    else
      {:ok, Map.put(incomplete_channels_acc, frame.channel_id, channel_updated), batches_acc, sequences_acc}
    end
  end

  defp handle_channel(
         channel,
         incomplete_channels_acc,
         batches_acc,
         sequences_acc,
         genesis_block_l2,
         json_rpc_named_arguments_l2
       ) do
    frame_sequence_last = List.first(sequences_acc)
    frame_sequence_id = next_frame_sequence_id(frame_sequence_last)

    {bytes, l1_transaction_hashes} =
      0..(Enum.count(channel.frames) - 1)
      |> Enum.reduce({<<>>, []}, fn frame_number, {bytes_acc, tx_hashes_acc} ->
        frame = Map.get(channel.frames, frame_number)
        {bytes_acc <> frame.data, [frame.tx_hash | tx_hashes_acc]}
      end)

    batches_parsed =
      parse_frame_sequence(
        bytes,
        frame_sequence_id,
        channel.l1_timestamp,
        genesis_block_l2,
        json_rpc_named_arguments_l2
      )

    if batches_parsed == :error do
      Logger.error("Cannot parse frame sequence from these L1 transaction(s): #{inspect(l1_transaction_hashes)}")
    end

    seq = %{
      id: frame_sequence_id,
      l1_transaction_hashes: Enum.uniq(Enum.reverse(l1_transaction_hashes)),
      l1_timestamp: channel.l1_timestamp
    }

    new_incomplete_channels_acc =
      incomplete_channels_acc
      |> Map.delete(channel.id)
      |> remove_expired_channels()

    if batches_parsed == :error or Enum.empty?(batches_parsed) do
      {:ok, new_incomplete_channels_acc, batches_acc, sequences_acc}
    else
      {:ok, new_incomplete_channels_acc, batches_acc ++ batches_parsed, [seq | sequences_acc]}
    end
  end

  defp handle_l1_reorg(reorg_block, incomplete_channels) do
    incomplete_channels
    |> Enum.reduce(incomplete_channels, fn {channel_id, %{frames: frames} = channel}, acc ->
      updated_frames =
        frames
        |> Enum.filter(fn {_frame_number, %{block_number: block_number}} ->
          block_number < reorg_block
        end)
        |> Enum.into(%{})

      if Enum.empty?(updated_frames) do
        Map.delete(acc, channel_id)
      else
        Map.put(acc, channel_id, Map.put(channel, :frames, updated_frames))
      end
    end)
  end

  @doc """
    Removes rows from op_transaction_batches and op_frame_sequences tables written beginning from the L2 reorg block.
  """
  @spec handle_l2_reorg(non_neg_integer()) :: any()
  def handle_l2_reorg(reorg_block) do
    frame_sequence_ids =
      Repo.all(
        from(
          tb in OptimismTxnBatch,
          select: tb.frame_sequence_id,
          where: tb.l2_block_number >= ^reorg_block
        ),
        timeout: :infinity
      )

    {deleted_count, _} = Repo.delete_all(from(tb in OptimismTxnBatch, where: tb.l2_block_number >= ^reorg_block))

    Repo.delete_all(from(fs in FrameSequence, where: fs.id in ^frame_sequence_ids))

    if deleted_count > 0 do
      Logger.warning(
        "As L2 reorg was detected, all rows with l2_block_number >= #{reorg_block} were removed from the op_transaction_batches table. Number of removed rows: #{deleted_count}."
      )
    end
  end

  defp http_get_request(url) do
    case Application.get_env(:explorer, :http_adapter).get(url) do
      {:ok, %Response{body: body, status_code: 200}} ->
        Jason.decode(body)

      {:ok, %Response{body: body, status_code: _}} ->
        {:error, body}

      {:error, error} ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to Blockscout Blobs API: #{url}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:error, "Error while sending request to Blockscout Blobs API"}
    end
  end

  defp channel_complete?(channel) do
    last_frame_number =
      channel.frames
      |> Map.keys()
      |> Enum.max()

    Map.get(channel.frames, last_frame_number).is_last and last_frame_number == Enum.count(channel.frames) - 1
  end

  defp remove_expired_channels(channels_map) do
    now = DateTime.utc_now()

    Enum.reduce(channels_map, channels_map, fn {channel_id, %{timestamp: timestamp}}, channels_acc ->
      if DateTime.diff(now, timestamp) >= 86400 do
        Map.delete(channels_acc, channel_id)
      else
        channels_acc
      end
    end)
  end

  defp input_to_frame("0x" <> input) do
    input
    |> Base.decode16!(case: :mixed)
    |> input_to_frame()
  end

  defp input_to_frame(input_binary) do
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

  defp next_frame_sequence_id(last_known_sequence) when is_nil(last_known_sequence) do
    last_known_id =
      Repo.one(
        from(
          fs in FrameSequence,
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
         genesis_block_l2,
         json_rpc_named_arguments_l2
       ) do
    uncompressed_bytes = zlib_decompress(bytes)

    batches =
      Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), {uncompressed_bytes, []}, fn _i, {remainder, batch_acc} ->
        try do
          {decoded, new_remainder} = ExRLP.decode(remainder, stream: true)

          <<version>> = binary_part(decoded, 0, 1)
          content = binary_part(decoded, 1, byte_size(decoded) - 1)

          new_batch_acc =
            cond do
              version == 0 ->
                handle_v0_batch(content, id, l1_timestamp, batch_acc)

              version <= 2 ->
                # parsing the span batch
                handle_v1_batch(content, id, l1_timestamp, genesis_block_l2, batch_acc)

              true ->
                Logger.error("Unsupported batch version ##{version}")
                :error
            end

          if byte_size(new_remainder) > 0 and new_batch_acc != :error do
            {:cont, {new_remainder, new_batch_acc}}
          else
            {:halt, new_batch_acc}
          end
        rescue
          _ -> {:halt, :error}
        end
      end)

    if batches == :error do
      :error
    else
      batches = Enum.reverse(batches)

      numbers_by_hashes =
        batches
        |> Stream.filter(&Map.has_key?(&1, :parent_hash))
        |> Enum.map(fn batch -> batch.parent_hash end)
        |> get_block_numbers_by_hashes(json_rpc_named_arguments_l2)

      Enum.map(batches, &parent_hash_to_l2_block_number(&1, numbers_by_hashes))
    end
  end

  defp handle_v0_batch(content, frame_sequence_id, l1_timestamp, batch_acc) do
    content_decoded = ExRLP.decode(content)

    batch = %{
      parent_hash: Enum.at(content_decoded, 0),
      frame_sequence_id: frame_sequence_id,
      l1_timestamp: l1_timestamp
    }

    [batch | batch_acc]
  end

  defp handle_v1_batch(content, frame_sequence_id, l1_timestamp, genesis_block_l2, batch_acc) do
    {rel_timestamp, content_remainder} = LEB128.decode(content)

    # skip l1_origin_num
    {_l1_origin_num, checks_and_payload} = LEB128.decode(content_remainder)

    # skip `parent_check` and `l1_origin_check` fields (20 bytes each)
    # and read the block count
    {block_count, _} =
      checks_and_payload
      |> binary_part(40, byte_size(checks_and_payload) - 40)
      |> LEB128.decode()

    # the first and last L2 blocks in the span
    span_start = div(rel_timestamp, @op_chain_block_time) + genesis_block_l2
    span_end = span_start + block_count - 1

    cond do
      rem(rel_timestamp, @op_chain_block_time) != 0 ->
        Logger.error("rel_timestamp is not divisible by #{@op_chain_block_time}. We ignore the span batch.")
        batch_acc

      block_count <= 0 ->
        Logger.error("Empty span batch found. We ignore it.")
        batch_acc

      true ->
        span_start..span_end
        |> Enum.reduce(batch_acc, fn l2_block_number, batch_acc ->
          [
            %{
              l2_block_number: l2_block_number,
              frame_sequence_id: frame_sequence_id,
              l1_timestamp: l1_timestamp
            }
            | batch_acc
          ]
        end)
    end
  end

  defp parent_hash_to_l2_block_number(batch, numbers_by_hashes) do
    if Map.has_key?(batch, :parent_hash) do
      number = Map.get(numbers_by_hashes, batch.parent_hash)

      batch
      |> Map.put(:l2_block_number, number + 1)
      |> Map.delete(:parent_hash)
    else
      batch
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

  defp txs_filter(transactions_params, batch_submitter, batch_inbox) do
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
  end

  defp zlib_decompress(bytes) do
    z = :zlib.open()
    :zlib.inflateInit(z)

    uncompressed_bytes =
      try do
        zlib_inflate(z, bytes)
      rescue
        _ -> <<>>
      end

    try do
      :zlib.inflateEnd(z)
    rescue
      _ -> nil
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
end
