defmodule Indexer.Fetcher.PolygonZkevm.TransactionBatch do
  @moduledoc """
  Fills polygon_zkevm_transaction_batches DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC, only: [integer_to_quantity: 1, json_rpc: 2, quantity_to_integer: 1]

  alias Explorer.Chain
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.PolygonZkevm.Reader
  alias Indexer.Helper
  alias Indexer.Prometheus.Instrumenter

  @zero_hash "0000000000000000000000000000000000000000000000000000000000000000"

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
    Logger.metadata(fetcher: :polygon_zkevm_transaction_batches)

    config = Application.get_all_env(:indexer)[Indexer.Fetcher.PolygonZkevm.TransactionBatch]
    chunk_size = config[:chunk_size]
    recheck_interval = config[:recheck_interval]

    ignore_numbers =
      config[:ignore_numbers]
      |> String.trim()
      |> String.split(",")
      |> Enum.map(fn ignore_number ->
        ignore_number
        |> String.trim()
        |> String.to_integer()
      end)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    Process.send_after(self(), :continue, 2000)

    {:ok,
     %{
       chunk_size: chunk_size,
       ignore_numbers: ignore_numbers,
       json_rpc_named_arguments: args[:json_rpc_named_arguments],
       prev_latest_batch_number: 0,
       prev_virtual_batch_number: 0,
       prev_verified_batch_number: 0,
       recheck_interval: recheck_interval
     }}
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          chunk_size: chunk_size,
          ignore_numbers: ignore_numbers,
          json_rpc_named_arguments: json_rpc_named_arguments,
          prev_latest_batch_number: prev_latest_batch_number,
          prev_virtual_batch_number: prev_virtual_batch_number,
          prev_verified_batch_number: prev_verified_batch_number,
          recheck_interval: recheck_interval
        } = state
      ) do
    {latest_batch_number, virtual_batch_number, verified_batch_number} =
      fetch_latest_batch_numbers(json_rpc_named_arguments)

    {new_state, handle_duration} =
      if latest_batch_number > prev_latest_batch_number or virtual_batch_number > prev_virtual_batch_number or
           verified_batch_number > prev_verified_batch_number do
        start_batch_number = Reader.last_verified_batch_number() + 1
        end_batch_number = latest_batch_number

        log_message =
          ""
          |> make_log_message(latest_batch_number, prev_latest_batch_number, "latest")
          |> make_log_message(virtual_batch_number, prev_virtual_batch_number, "virtual")
          |> make_log_message(verified_batch_number, prev_verified_batch_number, "verified")

        Logger.info(log_message <> "Handling the batch range #{start_batch_number}..#{end_batch_number}.")

        {handle_duration, _} =
          :timer.tc(fn ->
            handle_batch_range(
              start_batch_number,
              end_batch_number,
              json_rpc_named_arguments,
              chunk_size,
              ignore_numbers
            )
          end)

        {
          %{
            state
            | prev_latest_batch_number: latest_batch_number,
              prev_virtual_batch_number: virtual_batch_number,
              prev_verified_batch_number: verified_batch_number
          },
          div(handle_duration, 1000)
        }
      else
        {state, 0}
      end

    Process.send_after(self(), :continue, max(:timer.seconds(recheck_interval) - handle_duration, 0))

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp handle_batch_range(start_batch_number, end_batch_number, json_rpc_named_arguments, chunk_size, ignore_numbers) do
    start_batch_number..end_batch_number
    |> Enum.chunk_every(chunk_size)
    |> Enum.each(fn chunk ->
      chunk_start = List.first(chunk)
      chunk_end = List.last(chunk)

      log_batches_chunk_handling(chunk_start, chunk_end, start_batch_number, end_batch_number)
      fetch_and_save_batches(chunk_start, chunk_end, json_rpc_named_arguments, ignore_numbers)
    end)
  end

  defp log_batches_chunk_handling(chunk_start, chunk_end, start_block, end_block) do
    target_range =
      if chunk_start != start_block or chunk_end != end_block do
        percentage =
          (chunk_end - start_block + 1)
          |> Decimal.div(end_block - start_block + 1)
          |> Decimal.mult(100)
          |> Decimal.round(2)
          |> Decimal.to_string()

        " Target range: #{start_block}..#{end_block}. Progress: #{percentage}%"
      else
        ""
      end

    if chunk_start == chunk_end do
      Logger.info("Handling batch ##{chunk_start}.#{target_range}")
    else
      Logger.info("Handling batch range #{chunk_start}..#{chunk_end}.#{target_range}")
    end
  end

  defp make_log_message(prev_message, batch_number, prev_batch_number, type) do
    if batch_number > prev_batch_number do
      prev_message <>
        "Found a new #{type} batch number #{batch_number}. Previous #{type} batch number is #{prev_batch_number}. "
    else
      prev_message
    end
  end

  defp fetch_and_save_batches(batch_start, batch_end, json_rpc_named_arguments, ignore_numbers) do
    {:ok, responses} = perform_jsonrpc_requests(batch_start, batch_end, json_rpc_named_arguments, ignore_numbers)

    # For every batch info extract batches' L1 sequence transaction and L1 verify transaction
    {sequence_hashes, verify_hashes} =
      responses
      |> Enum.reduce({[], []}, fn res, {sequences, verifies} = _acc ->
        send_sequences_transaction_hash = get_transaction_hash(res.result, "sendSequencesTxHash")
        verify_batch_transaction_hash = get_transaction_hash(res.result, "verifyBatchTxHash")

        sequences =
          if send_sequences_transaction_hash != @zero_hash do
            [Base.decode16!(send_sequences_transaction_hash, case: :mixed) | sequences]
          else
            sequences
          end

        verifies =
          if verify_batch_transaction_hash != @zero_hash do
            [Base.decode16!(verify_batch_transaction_hash, case: :mixed) | verifies]
          else
            verifies
          end

        {sequences, verifies}
      end)

    # All L1 transactions in one list without repetition
    l1_transaction_hashes = Enum.uniq(sequence_hashes ++ verify_hashes)

    # Receive all IDs for L1 transactions
    hash_to_id =
      l1_transaction_hashes
      |> Reader.lifecycle_transactions()
      |> Enum.reduce(%{}, fn {hash, id}, acc ->
        Map.put(acc, hash.bytes, id)
      end)

    # For every batch build batch representation, collect associated L1 and L2 transactions
    {batches_to_import, l2_transactions_to_import, l1_transactions_to_import, _, _} =
      responses
      |> Enum.reduce({[], [], [], Reader.next_id(), hash_to_id}, fn res,
                                                                    {batches, l2_transactions, l1_transactions, next_id,
                                                                     hash_to_id} = _acc ->
        number = quantity_to_integer(Map.get(res.result, "number"))

        # the timestamp is undefined for unfinalized batches
        timestamp =
          case DateTime.from_unix(quantity_to_integer(Map.get(res.result, "timestamp", 0xFFFFFFFFFFFFFFFF))) do
            {:ok, ts} -> ts
            _ -> nil
          end

        l2_transaction_hashes = Map.get(res.result, "transactions")
        global_exit_root = Map.get(res.result, "globalExitRoot")
        acc_input_hash = Map.get(res.result, "accInputHash")
        state_root = Map.get(res.result, "stateRoot")

        # Get ID for sequence transaction (new ID if the batch is just sequenced)
        {sequence_id, l1_transactions, next_id, hash_to_id} =
          res.result
          |> get_transaction_hash("sendSequencesTxHash")
          |> handle_transaction_hash(hash_to_id, next_id, l1_transactions, false)

        # Get ID for verify transaction (new ID if the batch is just verified)
        {verify_id, l1_transactions, next_id, hash_to_id} =
          res.result
          |> get_transaction_hash("verifyBatchTxHash")
          |> handle_transaction_hash(hash_to_id, next_id, l1_transactions, true)

        # Associate every transaction from batch with the batch number
        l2_transactions_append =
          l2_transaction_hashes
          |> Kernel.||([])
          |> Enum.map(fn l2_transaction_hash ->
            %{
              batch_number: number,
              hash: l2_transaction_hash
            }
          end)

        batch = %{
          number: number,
          timestamp: timestamp,
          l2_transactions_count: Enum.count(l2_transactions_append),
          global_exit_root: global_exit_root,
          acc_input_hash: acc_input_hash,
          state_root: state_root,
          sequence_id: sequence_id,
          verify_id: verify_id
        }

        {[batch | batches], l2_transactions ++ l2_transactions_append, l1_transactions, next_id, hash_to_id}
      end)

    # Update batches list, L1 transactions list and L2 transaction list
    {:ok, _} =
      Chain.import(%{
        polygon_zkevm_lifecycle_transactions: %{params: l1_transactions_to_import},
        polygon_zkevm_transaction_batches: %{params: batches_to_import},
        polygon_zkevm_batch_transactions: %{params: l2_transactions_to_import},
        timeout: :infinity
      })

    last_batch =
      batches_to_import
      |> Enum.max_by(& &1.number, fn -> nil end)

    if last_batch do
      Instrumenter.set_latest_batch(last_batch.number, last_batch.timestamp)
    end

    confirmed_batches =
      Enum.filter(batches_to_import, fn batch -> not is_nil(batch.sequence_id) and batch.sequence_id > 0 end)

    # Publish update for open batches Views in BS app with the new confirmed batches
    if not Enum.empty?(confirmed_batches) do
      Publisher.broadcast([{:zkevm_confirmed_batches, confirmed_batches}], :realtime)
    end
  end

  defp perform_jsonrpc_requests(batch_start, batch_end, json_rpc_named_arguments, ignore_numbers) do
    # For every batch from batch_start to batch_end request the batch info
    requests =
      batch_start
      |> Range.new(batch_end, 1)
      |> Enum.reject(fn batch_number ->
        if Enum.member?(ignore_numbers, batch_number) do
          Logger.warning("The batch #{batch_number} will be ignored.")
          true
        else
          false
        end
      end)
      |> Enum.map(fn batch_number ->
        EthereumJSONRPC.request(%{
          id: batch_number,
          method: "zkevm_getBatchByNumber",
          params: [integer_to_quantity(batch_number), false]
        })
      end)

    if requests == [] do
      {:ok, []}
    else
      error_message =
        &"Cannot call zkevm_getBatchByNumber for the batch range #{batch_start}..#{batch_end}. Error: #{inspect(&1)}"

      Helper.repeated_call(&json_rpc/2, [requests, json_rpc_named_arguments], error_message, 3)
    end
  end

  defp fetch_latest_batch_numbers(json_rpc_named_arguments) do
    requests = [
      EthereumJSONRPC.request(%{id: 0, method: "zkevm_batchNumber", params: []}),
      EthereumJSONRPC.request(%{id: 1, method: "zkevm_virtualBatchNumber", params: []}),
      EthereumJSONRPC.request(%{id: 2, method: "zkevm_verifiedBatchNumber", params: []})
    ]

    error_message = &"Cannot call zkevm_batchNumber. Error: #{inspect(&1)}"

    {:ok, responses} = Helper.repeated_call(&json_rpc/2, [requests, json_rpc_named_arguments], error_message, 3)

    latest_batch_number =
      Enum.find_value(responses, fn resp -> if resp.id == 0, do: quantity_to_integer(resp.result) end)

    virtual_batch_number =
      Enum.find_value(responses, fn resp -> if resp.id == 1, do: quantity_to_integer(resp.result) end)

    verified_batch_number =
      Enum.find_value(responses, fn resp -> if resp.id == 2, do: quantity_to_integer(resp.result) end)

    {latest_batch_number, virtual_batch_number, verified_batch_number}
  end

  defp get_transaction_hash(result, type) do
    case Map.get(result, type) do
      "0x" <> transaction_hash -> transaction_hash
      nil -> @zero_hash
    end
  end

  defp handle_transaction_hash(encoded_transaction_hash, hash_to_id, next_id, l1_transactions, is_verify) do
    if encoded_transaction_hash != @zero_hash do
      transaction_hash = Base.decode16!(encoded_transaction_hash, case: :mixed)

      id = Map.get(hash_to_id, transaction_hash)

      if is_nil(id) do
        {next_id, [%{id: next_id, hash: transaction_hash, is_verify: is_verify} | l1_transactions], next_id + 1,
         Map.put(hash_to_id, transaction_hash, next_id)}
      else
        {id, l1_transactions, next_id, hash_to_id}
      end
    else
      {nil, l1_transactions, next_id, hash_to_id}
    end
  end
end
