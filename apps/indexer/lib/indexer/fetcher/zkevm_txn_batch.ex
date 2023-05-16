defmodule Indexer.Fetcher.ZkevmTxnBatch do
  @moduledoc """
  Fills zkevm_transaction_batches DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [integer_to_quantity: 1, json_rpc: 2, quantity_to_integer: 1]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{ZkevmLifecycleTxn, ZkevmTxnBatch}

  @batch_range_size 20
  @recheck_latest_batch_interval 60
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
    Logger.metadata(fetcher: :zkevm_txn_batches)
    # Logger.configure(truncate: :infinity)

    Process.send(self(), :continue, [])

    {:ok,
     %{
       json_rpc_named_arguments: args[:json_rpc_named_arguments],
       prev_latest_batch_number: 0,
       prev_virtual_batch_number: 0,
       prev_verified_batch_number: 0
     }}
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          json_rpc_named_arguments: json_rpc_named_arguments,
          prev_latest_batch_number: prev_latest_batch_number,
          prev_virtual_batch_number: prev_virtual_batch_number,
          prev_verified_batch_number: prev_verified_batch_number
        } = state
      ) do
    {latest_batch_number, virtual_batch_number, verified_batch_number} =
      fetch_latest_batch_numbers(json_rpc_named_arguments)

    {new_state, handle_duration} =
      if latest_batch_number > prev_latest_batch_number or virtual_batch_number > prev_virtual_batch_number or
           verified_batch_number > prev_verified_batch_number do
        start_batch_number = get_last_verified_batch_number() + 1
        end_batch_number = latest_batch_number

        log_message =
          if latest_batch_number > prev_latest_batch_number do
            "Found a new latest batch number #{latest_batch_number}. Previous batch number is #{prev_latest_batch_number}. "
          else
            ""
          end

        log_message =
          if virtual_batch_number > prev_virtual_batch_number do
            log_message <>
              "Found a new virtual batch number #{virtual_batch_number}. Previous virtual batch number is #{prev_virtual_batch_number}. "
          else
            log_message
          end

        log_message =
          if verified_batch_number > prev_verified_batch_number do
            log_message <>
              "Found a new verified batch number #{verified_batch_number}. Previous verified batch number is #{prev_verified_batch_number}. "
          else
            log_message
          end

        Logger.info(log_message <> "Handling the batch range #{start_batch_number}..#{end_batch_number}.")

        {handle_duration, _} =
          :timer.tc(fn -> handle_batch_range(start_batch_number, end_batch_number, json_rpc_named_arguments) end)

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

    Process.send_after(self(), :continue, max(:timer.seconds(@recheck_latest_batch_interval) - handle_duration, 0))

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp get_last_verified_batch_number do
    query =
      from(tb in ZkevmTxnBatch,
        select: tb.number,
        where: not is_nil(tb.verify_id),
        order_by: [desc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||(0)
  end

  defp get_next_id do
    query =
      from(lt in ZkevmLifecycleTxn,
        select: lt.id,
        order_by: [desc: lt.id],
        limit: 1
      )

    last_id =
      query
      |> Repo.one()
      |> Kernel.||(0)

    last_id + 1
  end

  defp handle_batch_range(start_batch_number, end_batch_number, json_rpc_named_arguments) do
    chunks_number = ceil((end_batch_number - start_batch_number + 1) / @batch_range_size)

    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    Enum.each(chunk_range, fn current_chunk ->
      chunk_start = start_batch_number + @batch_range_size * current_chunk
      chunk_end = min(chunk_start + @batch_range_size - 1, end_batch_number)

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

    query =
      from(
        lt in ZkevmLifecycleTxn,
        select: {lt.hash, lt.id},
        where: lt.hash in ^l1_tx_hashes
      )

    hash_to_id =
      query
      |> Repo.all(timeout: :infinity)
      |> Enum.reduce(%{}, fn {hash, id}, acc ->
        Map.put(acc, hash.bytes, id)
      end)

    {batches_to_import, l2_txs_to_import, l1_txs_to_import, _, _} =
      responses
      |> Enum.reduce({[], [], [], get_next_id(), hash_to_id}, fn res,
                                                                 {batches, l2_txs, l1_txs, next_id, hash_to_id} = _acc ->
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

        batch = %{
          number: number,
          timestamp: timestamp,
          global_exit_root: global_exit_root,
          acc_input_hash: acc_input_hash,
          state_root: state_root,
          sequence_id: sequence_id,
          verify_id: verify_id
        }

        l2_txs_append =
          l2_transaction_hashes
          |> Kernel.||([])
          |> Enum.map(fn l2_tx_hash ->
            %{
              batch_number: number,
              hash: l2_tx_hash
            }
          end)

        {[batch | batches], l2_txs ++ l2_txs_append, l1_txs, next_id, hash_to_id}
      end)

    {:ok, _} =
      Chain.import(%{
        zkevm_lifecycle_txns: %{params: l1_txs_to_import},
        zkevm_txn_batches: %{params: batches_to_import},
        zkevm_batch_txns: %{params: l2_txs_to_import},
        timeout: :infinity
      })
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
