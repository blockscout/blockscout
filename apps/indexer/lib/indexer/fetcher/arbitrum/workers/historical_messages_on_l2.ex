defmodule Indexer.Fetcher.Arbitrum.Workers.HistoricalMessagesOnL2 do
  @moduledoc """
  TBD
  """

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber
  alias EthereumJSONRPC.Transaction, as: TransactionByRPC

  alias Explorer.Chain

  alias Indexer.Fetcher.Arbitrum.Messaging
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Logging, Rpc}

  require Logger

  def discover_historical_messages_from_l2(end_block, _) when is_nil(end_block) do
    {:ok, nil}
  end

  def discover_historical_messages_from_l2(end_block, _) when end_block < 0 do
    {:ok, 0}
  end

  def discover_historical_messages_from_l2(end_block, state) do
    start_block = max(0, end_block - state.config.messages_from_l2_blocks_depth + 1)

    if Db.indexed_blocks?(start_block, end_block) do
      do_discover_historical_messages_from_l2(start_block, end_block)
    else
      Logger.warning(
        "Not able to discover historical messages from L2, some blocks in #{start_block}..#{end_block} not indexed"
      )

      {:ok, end_block + 1}
    end
  end

  defp do_discover_historical_messages_from_l2(start_block, end_block) do
    Logger.info("Block range for discovery historical messages from L2: #{start_block}..#{end_block}")

    logs = Db.l2_to_l1_logs(start_block, end_block)

    unless logs == [] do
      messages =
        logs
        |> Messaging.handle_filtered_l2_to_l1_messages()

      import_to_db(messages)
    end

    {:ok, start_block}
  end

  def discover_historical_messages_to_l2(end_block, _) when is_nil(end_block) do
    {:ok, nil}
  end

  def discover_historical_messages_to_l2(end_block, _) when end_block < 0 do
    {:ok, 0}
  end

  def discover_historical_messages_to_l2(end_block, state) do
    start_block = max(0, end_block - state.config.messages_to_l2_blocks_depth + 1)

    # Although indexing blocks is not necessary to determine the completion of L1-to-L2 messages,
    # for database consistency, it is preferable to delay marking these messages as completed.
    if Db.indexed_blocks?(start_block, end_block) do
      do_discover_historical_messages_to_l2(start_block, end_block, state.config)
    else
      Logger.warning(
        "Not able to discover historical messages to L2, some blocks in #{start_block}..#{end_block} not indexed"
      )

      {:ok, end_block + 1}
    end
  end

  defp do_discover_historical_messages_to_l2(start_block, end_block, config) do
    Logger.info("Block range for discovery historical messages to L2: #{start_block}..#{end_block}")

    {messages, _} =
      start_block..end_block
      |> Enum.chunk_every(config.rollup_rpc.chunk_size)
      |> Enum.reduce({[], 0}, fn chunk, {messages_acc, chunks_counter} ->
        Logging.log_details_chunk_handling(
          "Collecting rollup data",
          {"block", "blocks"},
          chunk,
          chunks_counter,
          end_block - start_block + 1
        )

        # Since DB does not contain the field RequestId specific to Arbitrum
        # all transactions will be requested from the rollup RPC endpoint.
        # The catchup process intended to be run once and only for the BS instance
        # which are already exist, so it does not make sense to introduce
        # the new field in DB
        requests = build_block_by_number_requests(chunk)

        messages =
          requests
          |> Rpc.make_chunked_request(config.rollup_rpc.json_rpc_named_arguments, "eth_getBlockByNumber")
          |> get_transactions()
          |> Enum.map(fn tx ->
            tx
            |> TransactionByRPC.to_elixir()
            |> TransactionByRPC.elixir_to_params()
          end)
          |> Messaging.filter_l1_to_l2_messages(false)

        {messages ++ messages_acc, chunks_counter + length(chunk)}
      end)

    unless messages == [] do
      Logger.info("#{length(messages)} completions of L1-to-L2 messages will be imported")
    end

    import_to_db(messages)

    {:ok, start_block}
  end

  defp build_block_by_number_requests(block_numbers) do
    block_numbers
    |> Enum.reduce([], fn block_num, requests_list ->
      [
        BlockByNumber.request(%{
          id: block_num,
          number: block_num
        })
        | requests_list
      ]
    end)
  end

  defp get_transactions(blocks_by_rpc) do
    blocks_by_rpc
    |> Enum.reduce([], fn block_by_rpc, txs ->
      block_by_rpc["transactions"] ++ txs
    end)
  end

  defp import_to_db(messages) do
    {:ok, _} =
      Chain.import(%{
        arbitrum_messages: %{params: messages},
        timeout: :infinity
      })
  end
end
