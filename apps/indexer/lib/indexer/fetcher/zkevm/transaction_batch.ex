defmodule Indexer.Fetcher.Zkevm.TransactionBatch do
  @moduledoc """
  Fills zkevm_transaction_batches DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC, only: [integer_to_quantity: 1, json_rpc: 2, quantity_to_integer: 1]

  alias Explorer.Chain
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Zkevm.Reader

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
    Logger.metadata(fetcher: :zkevm_transaction_batches)

    config = Application.get_all_env(:indexer)[Indexer.Fetcher.Zkevm.TransactionBatch]
    chunk_size = config[:chunk_size]
    recheck_interval = config[:recheck_interval]

    Process.send(self(), :continue, [])

    {:ok,
     %{
       chunk_size: chunk_size,
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
            handle_batch_range(start_batch_number, end_batch_number, json_rpc_named_arguments, chunk_size)
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

  defp handle_batch_range(start_batch_number, end_batch_number, json_rpc_named_arguments, chunk_size) do
    start_batch_number..end_batch_number
    |> Enum.chunk_every(chunk_size)
    |> Enum.each(fn chunk ->
      chunk_start = List.first(chunk)
      chunk_end = List.last(chunk)

      log_batches_chunk_handling(chunk_start, chunk_end, start_batch_number, end_batch_number)
      fetch_and_save_batches(chunk_start, chunk_end, json_rpc_named_arguments)
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

  defp fetch_and_save_batches(batch_start, batch_end, json_rpc_named_arguments) do
    requests =
      batch_start
      |> Range.new(batch_end, 1)
      |> Enum.map(fn batch_number ->
        EthereumJSONRPC.request(%{
          id: batch_number,
          method: "zkevm_getBatchByNumber",
          params: [integer_to_quantity(batch_number), false]
        })
      end)

    error_message =
      &"Cannot call zkevm_getBatchByNumber for the batch range #{batch_start}..#{batch_end}. Error: #{inspect(&1)}"

    {:ok, responses} = repeated_call(&json_rpc/2, [requests, json_rpc_named_arguments], error_message, 3)

    {sequence_hashes, verify_hashes} =
      responses
      |> Enum.reduce({[], []}, fn res, {sequences, verifies} = _acc ->
        send_sequences_tx_hash = get_tx_hash(res.result, "sendSequencesTxHash")
        verify_batch_tx_hash = get_tx_hash(res.result, "verifyBatchTxHash")

        sequences =
          if send_sequences_tx_hash != @zero_hash do
            [Base.decode16!(send_sequences_tx_hash, case: :mixed) | sequences]
          else
            sequences
          end

        verifies =
          if verify_batch_tx_hash != @zero_hash do
            [Base.decode16!(verify_batch_tx_hash, case: :mixed) | verifies]
          else
            verifies
          end

        {sequences, verifies}
      end)

    l1_tx_hashes = Enum.uniq(sequence_hashes ++ verify_hashes)

    hash_to_id =
      l1_tx_hashes
      |> Reader.lifecycle_transactions()
      |> Enum.reduce(%{}, fn {hash, id}, acc ->
        Map.put(acc, hash.bytes, id)
      end)

    {batches_to_import, l2_txs_to_import, l1_txs_to_import, _, _} =
      responses
      |> Enum.reduce({[], [], [], Reader.next_id(), hash_to_id}, fn res,
                                                                    {batches, l2_txs, l1_txs, next_id, hash_to_id} =
                                                                      _acc ->
        number = quantity_to_integer(Map.get(res.result, "number"))
        {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(res.result, "timestamp")))
        l2_transaction_hashes = Map.get(res.result, "transactions")
        global_exit_root = Map.get(res.result, "globalExitRoot")
        acc_input_hash = Map.get(res.result, "accInputHash")
        state_root = Map.get(res.result, "stateRoot")

        {sequence_id, l1_txs, next_id, hash_to_id} =
          res.result
          |> get_tx_hash("sendSequencesTxHash")
          |> handle_tx_hash(hash_to_id, next_id, l1_txs, false)

        {verify_id, l1_txs, next_id, hash_to_id} =
          res.result
          |> get_tx_hash("verifyBatchTxHash")
          |> handle_tx_hash(hash_to_id, next_id, l1_txs, true)

        l2_txs_append =
          l2_transaction_hashes
          |> Kernel.||([])
          |> Enum.map(fn l2_tx_hash ->
            %{
              batch_number: number,
              hash: l2_tx_hash
            }
          end)

        batch = %{
          number: number,
          timestamp: timestamp,
          l2_transactions_count: Enum.count(l2_txs_append),
          global_exit_root: global_exit_root,
          acc_input_hash: acc_input_hash,
          state_root: state_root,
          sequence_id: sequence_id,
          verify_id: verify_id
        }

        {[batch | batches], l2_txs ++ l2_txs_append, l1_txs, next_id, hash_to_id}
      end)

    {:ok, _} =
      Chain.import(%{
        zkevm_lifecycle_transactions: %{params: l1_txs_to_import},
        zkevm_transaction_batches: %{params: batches_to_import},
        zkevm_batch_transactions: %{params: l2_txs_to_import},
        timeout: :infinity
      })

    confirmed_batches =
      Enum.filter(batches_to_import, fn batch -> not is_nil(batch.sequence_id) and batch.sequence_id > 0 end)

    if not Enum.empty?(confirmed_batches) do
      Publisher.broadcast([{:zkevm_confirmed_batches, confirmed_batches}], :realtime)
    end
  end

  defp fetch_latest_batch_numbers(json_rpc_named_arguments) do
    requests = [
      EthereumJSONRPC.request(%{id: 0, method: "zkevm_batchNumber", params: []}),
      EthereumJSONRPC.request(%{id: 1, method: "zkevm_virtualBatchNumber", params: []}),
      EthereumJSONRPC.request(%{id: 2, method: "zkevm_verifiedBatchNumber", params: []})
    ]

    error_message = &"Cannot call zkevm_batchNumber. Error: #{inspect(&1)}"

    {:ok, responses} = repeated_call(&json_rpc/2, [requests, json_rpc_named_arguments], error_message, 3)

    latest_batch_number =
      Enum.find_value(responses, fn resp -> if resp.id == 0, do: quantity_to_integer(resp.result) end)

    virtual_batch_number =
      Enum.find_value(responses, fn resp -> if resp.id == 1, do: quantity_to_integer(resp.result) end)

    verified_batch_number =
      Enum.find_value(responses, fn resp -> if resp.id == 2, do: quantity_to_integer(resp.result) end)

    {latest_batch_number, virtual_batch_number, verified_batch_number}
  end

  defp get_tx_hash(result, type) do
    case Map.get(result, type) do
      "0x" <> tx_hash -> tx_hash
      nil -> @zero_hash
    end
  end

  defp handle_tx_hash(encoded_tx_hash, hash_to_id, next_id, l1_txs, is_verify) do
    if encoded_tx_hash != @zero_hash do
      tx_hash = Base.decode16!(encoded_tx_hash, case: :mixed)

      id = Map.get(hash_to_id, tx_hash)

      if is_nil(id) do
        {next_id, [%{id: next_id, hash: tx_hash, is_verify: is_verify} | l1_txs], next_id + 1,
         Map.put(hash_to_id, tx_hash, next_id)}
      else
        {id, l1_txs, next_id, hash_to_id}
      end
    else
      {nil, l1_txs, next_id, hash_to_id}
    end
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
end
