defmodule Indexer.Fetcher.ZkSync.TransactionBatch do
  @moduledoc """
    Discovers new batches and fills zksync_transaction_batches DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]

  alias Explorer.Chain
  # alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.ZkSync.Reader
  alias Indexer.Fetcher.ZkSync.Helper
  import Indexer.Fetcher.ZkSync.Helper, only: [log_info: 1]

  @json_fields_to_exclude [:commit_tx_hash, :commit_timestamp, :prove_tx_hash, :prove_timestamp, :executed_tx_hash, :executed_timestamp]

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
    Logger.metadata(fetcher: :zksync_transaction_batches)

    config = Application.get_all_env(:indexer)[Indexer.Fetcher.ZkSync.TransactionBatch]
    chunk_size = config[:chunk_size]
    recheck_interval = config[:recheck_interval]
    batches_max_range = config[:batches_max_range]

    Process.send(self(), :init, [])

    {:ok,
     %{
       chunk_size: chunk_size,
       batches_max_range: batches_max_range,
       json_rpc_named_arguments: args[:json_rpc_named_arguments],
       latest_handled_batch_number: 0,
       recheck_interval: recheck_interval
     }}
  end

  @impl GenServer
  def handle_info(
        :init,
        %{json_rpc_named_arguments: json_rpc_named_arguments} = state
      ) do

    latest_handled_batch_number =
      cond do
        latest_handled_batch_number = Reader.latest_available_batch_number() ->
          latest_handled_batch_number - 1

        true ->
          log_info("No batches found in DB")
          Helper.fetch_latest_sealed_batch_number(json_rpc_named_arguments) - 1
      end

    Process.send_after(self(), :continue, 2000)

    log_info("The latest unfinalized batch number #{latest_handled_batch_number}")

    {:noreply, %{
                 state
                 | latest_handled_batch_number: latest_handled_batch_number
                }}
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          chunk_size: chunk_size,
          batches_max_range: batches_max_range,
          json_rpc_named_arguments: json_rpc_named_arguments,
          latest_handled_batch_number: latest_handled_batch_number,
          recheck_interval: recheck_interval
        } = state
      ) do
    latest_sealed_batch_number = Helper.fetch_latest_sealed_batch_number(json_rpc_named_arguments)

    log_info("Checking for a new batch")

    {new_state, handle_duration} =
      if latest_handled_batch_number < latest_sealed_batch_number do
        start_batch_number = latest_handled_batch_number + 1
        end_batch_number = min(latest_sealed_batch_number, latest_handled_batch_number + batches_max_range)

        log_info("Handling the batch range #{start_batch_number}..#{end_batch_number}")

        {handle_duration, _} =
          :timer.tc(fn ->
            handle_batch_range(start_batch_number, end_batch_number, %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size})
          end)

        {
          %{
            state
            | latest_handled_batch_number: end_batch_number
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

  defp collect_batches_details(batches_list, %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config) do
    batches_list_length = length(batches_list)

    {batches_details, _} =
      batches_list
      |> Enum.chunk_every(chunk_size)
      |> Enum.reduce({%{}, 0}, fn chunk, {details, a} ->
        Helper.log_details_chunk_handling("Collecting details", chunk, a * chunk_size, batches_list_length)
        requests =
          chunk
          |> Enum.map(fn batch_number ->
            EthereumJSONRPC.request(%{
              id: batch_number,
              method: "zks_getL1BatchDetails",
              params: [batch_number]
            })
          end)

        details = Helper.fetch_batches_details(requests, json_rpc_named_arguments)
        |> Enum.reduce(
          details,
          fn resp, details ->
            Map.put(details, resp.id, Helper.transform_batch_details_to_map(resp.result))
          end)

        {details, a + 1}
      end)

    batches_details
  end

  defp get_block_ranges(batches, %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config) do
    keys = Map.keys(batches)
    batches_list_length = length(keys)
    # The main goal of this reduce to get blocks ranges for every batch
    # by combining zks_getL1BatchBlockRange requests in chunks
    {updated_batches, _} =
      keys
      |> Enum.chunk_every(chunk_size)
      |> Enum.reduce({batches, 0}, fn batches_chunk, {batches_with_blockranges, a} = _acc ->
        Helper.log_details_chunk_handling("Collecting block ranges", batches_chunk, a * chunk_size, batches_list_length)

        # Execute requests list and extend the batches details with blocks ranges
        batches_with_blockranges =
          batches_chunk
          |> Enum.reduce([], fn batch_number, requests ->
            batch = Map.get(batches, batch_number)
            # Prepare requests list to get blocks ranges
            case is_nil(batch.start_block) or is_nil(batch.end_block) do
              true ->
                [ EthereumJSONRPC.request(%{
                  id: batch_number,
                  method: "zks_getL1BatchBlockRange",
                  params: [batch_number]
                }) | requests ]
              false ->
                requests
            end
          end)
          |> Helper.fetch_blocks_ranges(json_rpc_named_arguments)
          |> Enum.reduce(batches_with_blockranges, fn resp, batches_with_blockranges ->
            Map.update!(batches_with_blockranges, resp.id, fn batch ->
              [start_block, end_block] = resp.result
              Map.merge(batch, %{start_block: quantity_to_integer(start_block), end_block: quantity_to_integer(end_block)})
            end)
          end)

        {batches_with_blockranges, a + 1}
      end)

    updated_batches
  end

  defp get_l2_blocks_and_transactions(batches, %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config) do
    {blocks, chunked_requests, cur_chunk, cur_chunk_size} =
      Map.keys(batches)
      |> Enum.reduce({%{}, [], [], 0}, fn batch_number, {blocks, chunked_requests, cur_chunk, cur_chunk_size} = _acc ->
        batch = Map.get(batches, batch_number)
        # log_info("The batch #{batch_number} contains blocks range #{batch.start_block}..#{batch.end_block}")
        batch.start_block..batch.end_block
        |> Enum.chunk_every(chunk_size)
        |> Enum.reduce({blocks, chunked_requests, cur_chunk, cur_chunk_size}, fn blocks_range, {blks, chnkd_rqsts, c_chunk, c_chunk_size} = _acc ->
          blocks_range
          |> Enum.reduce({blks, chnkd_rqsts, c_chunk, c_chunk_size}, fn block_number, {blks, chnkd_rqsts, c_chunk, c_chunk_size} = _acc ->
            blks = Map.put(blks, block_number, %{batch_number: batch_number})
            c_chunk = [ EthereumJSONRPC.request(%{
              id: block_number,
              method: "eth_getBlockByNumber",
              params: [integer_to_quantity(block_number), false]
            }) | c_chunk ]
            if c_chunk_size + 1 == chunk_size do
              {blks, [ c_chunk | chnkd_rqsts ], [], 0}
            else
              {blks, chnkd_rqsts, c_chunk, c_chunk_size + 1}
            end
          end)
        end)
      end)

    chunked_requests =
      if cur_chunk_size > 0 do
        [ cur_chunk| chunked_requests ]
      else
        chunked_requests
      end

    {blocks, l2_txs_to_import} =
      chunked_requests
      |> Enum.reduce({blocks, []}, fn requests, {blocks, l2_txs} ->
        Helper.fetch_blocks_details(requests, json_rpc_named_arguments)
        |> extract_block_hash_and_transactions_list(blocks, l2_txs)
      end)

    # Check that amount of received transactions for a batch is correct
    Map.keys(batches)
    |> Enum.each(fn batch_number ->
      batch = Map.get(batches, batch_number)
      txs_in_batch = batch.l1_tx_count + batch.l2_tx_count
      ^txs_in_batch = Enum.count(l2_txs_to_import, fn tx ->
        tx.batch_number == batch_number
      end)
    end)

    {Map.values(blocks), l2_txs_to_import}
  end

  def extract_data_for_batch_range(start_batch_number, end_batch_number, config)
    when is_integer(start_batch_number) and is_integer(end_batch_number) and
         is_map(config) do
    start_batch_number..end_batch_number
    |> Enum.to_list()
    |> do_extract_data_for_batch_range(config)
  end

  def extract_data_for_batch_range(batches_list, config)
    when is_list(batches_list) and
         is_map(config) do
    batches_list
    |> do_extract_data_for_batch_range(config)
  end

  defp do_extract_data_for_batch_range(batches_list, config) when is_list(batches_list) do
    batches_to_import = collect_batches_details(batches_list, config)
    log_info("Collected details for #{length(Map.keys(batches_to_import))} batches")

    batches_to_import = get_block_ranges(batches_to_import, config)

    { l2_blocks_to_import, l2_txs_to_import } =
      get_l2_blocks_and_transactions(batches_to_import, config)
    log_info("Linked #{length(l2_blocks_to_import)} L2 blocks and #{length(l2_txs_to_import)} L2 transactions")

    {batches_to_import, l2_blocks_to_import, l2_txs_to_import}
  end

  defp handle_batch_range(start_batch_number, end_batch_number, config) do
    {batches_to_import, l2_blocks_to_import, l2_txs_to_import} =
      extract_data_for_batch_range(start_batch_number, end_batch_number, config)

    batches_list_to_import =
      Map.keys(batches_to_import)
      |> Enum.reduce([], fn batch_number, batches_list ->
        batch = Map.get(batches_to_import, batch_number)
        [ batch
          |> Map.drop(@json_fields_to_exclude) | batches_list ]
      end)

    {:ok, _} =
      Chain.import(%{
        zksync_transaction_batches: %{params: batches_list_to_import},
        zksync_batch_transactions: %{params: l2_txs_to_import},
        zksync_batch_blocks: %{params: l2_blocks_to_import},
        timeout: :infinity
      })
  end

  defp extract_block_hash_and_transactions_list(json_responses, l2_blocks, l2_txs) do
    json_responses
    |> Enum.reduce({l2_blocks, l2_txs}, fn resp, {l2_blocks, l2_txs} ->
        {block, l2_blocks} =
          Map.get_and_update(l2_blocks, resp.id, fn block ->
            {block, Map.put(block, :hash, Map.get(resp.result, "hash"))}
          end)

        l2_txs =
          Map.get(resp.result, "transactions")
          |> Kernel.||([])
          |> Enum.reduce(l2_txs, fn l2_tx_hash, l2_txs ->
            [ %{
              batch_number: block.batch_number,
              hash: l2_tx_hash
            } | l2_txs ]
          end)

        {l2_blocks, l2_txs}
      end)
  end

end
