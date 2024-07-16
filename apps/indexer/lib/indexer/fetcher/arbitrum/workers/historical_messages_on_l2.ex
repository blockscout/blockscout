defmodule Indexer.Fetcher.Arbitrum.Workers.HistoricalMessagesOnL2 do
  @moduledoc """
  Handles the discovery and processing of historical messages between Layer 1 (L1) and Layer 2 (L2) within an Arbitrum rollup.

  L1-to-L2 messages are discovered by requesting rollup transactions through RPC.
  This is necessary because some Arbitrum-specific fields are not included in the
  already indexed transactions within the database.

  L2-to-L1 messages are discovered by analyzing the logs of already indexed rollup
  transactions.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1, log_info: 1]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber
  alias EthereumJSONRPC.Transaction, as: TransactionByRPC

  alias Explorer.Chain

  alias Indexer.Fetcher.Arbitrum.Messaging
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Logging, Rpc}

  require Logger

  @doc """
    Initiates the discovery process for historical messages sent from L2 to L1 up to a specified block number.

    This function orchestrates the discovery of historical messages from L2 to L1
    by analyzing the rollup logs representing the `L2ToL1Tx` event. It determines
    the starting block for the discovery process and verifies that the relevant
    rollup block range has been indexed before proceeding with the discovery and
    data import. During the import process, each message is assigned the
    appropriate status based on the current rollup state.

    ## Parameters
    - `end_block`: The ending block number up to which the discovery should occur.
                   If `nil` or lesser than the indexer first block, the function
                   returns with no action taken.
    - `state`: Contains the operational configuration, including the depth of
               blocks to consider for the starting point of message discovery.

    ## Returns
    - `{:ok, nil}`: If `end_block` is `nil`, indicating no discovery action was required.
    - `{:ok, rollup_first_block}`: If `end_block` is lesser than the indexer first block,
      indicating that the "genesis" of the block chain was reached.
    - `{:ok, start_block}`: Upon successful discovery of historical messages, where
      `start_block` indicates the necessity to consider another block range in the next
      iteration of message discovery.
    - `{:ok, end_block + 1}`: If the required block range is not fully indexed,
      indicating that the next iteration of message discovery should start with the same
      block range.
  """
  @spec discover_historical_messages_from_l2(nil | integer(), %{
          :config => %{
            :messages_to_l2_blocks_depth => non_neg_integer(),
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: {:ok, nil | non_neg_integer()}
  def discover_historical_messages_from_l2(end_block, state)

  def discover_historical_messages_from_l2(end_block, _) when is_nil(end_block) do
    {:ok, nil}
  end

  def discover_historical_messages_from_l2(end_block, %{config: %{rollup_rpc: %{first_block: rollup_first_block}}})
      when is_integer(end_block) and end_block < rollup_first_block do
    {:ok, rollup_first_block}
  end

  def discover_historical_messages_from_l2(
        end_block,
        %{
          config: %{
            messages_from_l2_blocks_depth: messages_from_l2_blocks_depth,
            rollup_rpc: %{first_block: rollup_first_block}
          }
        } = _state
      )
      when is_integer(end_block) do
    start_block = max(rollup_first_block, end_block - messages_from_l2_blocks_depth + 1)

    if Db.indexed_blocks?(start_block, end_block) do
      do_discover_historical_messages_from_l2(start_block, end_block)
    else
      log_warning(
        "Not able to discover historical messages from L2, some blocks in #{start_block}..#{end_block} not indexed"
      )

      {:ok, end_block + 1}
    end
  end

  # Discovers and processes historical messages sent from L2 to L1 within a specified rollup block range.
  #
  # This function fetches relevant rollup logs from the database representing messages sent
  # from L2 to L1 (the `L2ToL1Tx` event) between the specified `start_block` and `end_block`.
  # If any logs are found, they are used to construct message structures, which are then
  # imported into the database. As part of the message construction, the appropriate status
  # of the message (initialized, sent, or confirmed) is determined based on the current rollup
  # state.
  #
  # ## Parameters
  # - `start_block`: The starting block number for the discovery range.
  # - `end_block`: The ending block number for the discovery range.
  #
  # ## Returns
  # - `{:ok, start_block}`: A tuple indicating successful processing, returning the initial
  #                         starting block number.
  defp do_discover_historical_messages_from_l2(start_block, end_block) do
    log_info("Block range for discovery historical messages from L2: #{start_block}..#{end_block}")

    logs = Db.l2_to_l1_logs(start_block, end_block)

    unless logs == [] do
      messages =
        logs
        |> Messaging.handle_filtered_l2_to_l1_messages(__MODULE__)

      import_to_db(messages)
    end

    {:ok, start_block}
  end

  @doc """
    Initiates the discovery of historical messages sent from L1 to L2 up to a specified block number.

    This function orchestrates the process of discovering historical L1-to-L2 messages within
    a given rollup block range, based on the existence of the `requestId` field in the rollup
    transaction body. Transactions are requested through RPC because already indexed
    transactions from the database cannot be utilized; the `requestId` field is not included
    in the transaction model. The function ensures that the block range has been indexed
    before proceeding with message discovery and import. The imported messages are marked as
    `:relayed`, as they represent completed actions from L1 to L2.

    ## Parameters
    - `end_block`: The ending block number for the discovery operation.
                   If `nil` or lesser than the indexer first block, the function
                   returns with no action taken.
    - `state`: The current state of the operation, containing configuration parameters
               including `messages_to_l2_blocks_depth`, `chunk_size`, and JSON RPC connection
               settings.

    ## Returns
    - `{:ok, nil}`: If `end_block` is `nil`, indicating no action was necessary.
    - `{:ok, rollup_first_block}`: If `end_block` is lesser than the indexer first block,
      indicating that the "genesis" of the block chain was reached.
    - `{:ok, start_block}`: On successful completion of historical message discovery, where
      `start_block` indicates the necessity to consider another block range in the next
      iteration of message discovery.
    - `{:ok, end_block + 1}`: If the required block range is not fully indexed, indicating
      that the next iteration of message discovery should start with the same block range.
  """
  @spec discover_historical_messages_to_l2(nil | integer(), %{
          :config => %{
            :messages_to_l2_blocks_depth => non_neg_integer(),
            :rollup_rpc => %{
              :chunk_size => non_neg_integer(),
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              optional(any()) => any()
            },
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: {:ok, nil | non_neg_integer()}
  def discover_historical_messages_to_l2(end_block, state)

  def discover_historical_messages_to_l2(end_block, _) when is_nil(end_block) do
    {:ok, nil}
  end

  def discover_historical_messages_to_l2(end_block, %{config: %{rollup_rpc: %{first_block: rollup_first_block}}})
      when is_integer(end_block) and end_block < rollup_first_block do
    {:ok, rollup_first_block}
  end

  def discover_historical_messages_to_l2(
        end_block,
        %{config: %{messages_to_l2_blocks_depth: _, rollup_rpc: %{first_block: _}} = config} = _state
      )
      when is_integer(end_block) do
    start_block = max(config.rollup_rpc.first_block, end_block - config.messages_to_l2_blocks_depth + 1)

    # Although indexing blocks is not necessary to determine the completion of L1-to-L2 messages,
    # for database consistency, it is preferable to delay marking these messages as completed.
    if Db.indexed_blocks?(start_block, end_block) do
      do_discover_historical_messages_to_l2(start_block, end_block, config)
    else
      log_warning(
        "Not able to discover historical messages to L2, some blocks in #{start_block}..#{end_block} not indexed"
      )

      {:ok, end_block + 1}
    end
  end

  # The function iterates through the block range in chunks, making RPC calls to fetch rollup block
  # data and extract transactions. Each transaction is filtered for L1-to-L2 messages based on
  # existence of `requestId` field in the transaction body, and then imported into the database.
  # The imported messages are marked as `:relayed` as they represent completed actions from L1 to L2.
  #
  # Already indexed transactions from the database cannot be used because the `requestId` field is
  # not included in the transaction model.
  #
  # ## Parameters
  # - `start_block`: The starting block number for the discovery range.
  # - `end_block`: The ending block number for the discovery range.
  # - `config`: The configuration map containing settings for RPC communication and chunk size.
  #
  # ## Returns
  # - `{:ok, start_block}`: A tuple indicating successful processing, returning the initial
  #                         starting block number.
  defp do_discover_historical_messages_to_l2(
         start_block,
         end_block,
         %{rollup_rpc: %{chunk_size: chunk_size, json_rpc_named_arguments: json_rpc_named_arguments}} = _config
       ) do
    log_info("Block range for discovery historical messages to L2: #{start_block}..#{end_block}")

    {messages, _} =
      start_block..end_block
      |> Enum.chunk_every(chunk_size)
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
          |> Rpc.make_chunked_request(json_rpc_named_arguments, "eth_getBlockByNumber")
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
      log_info("#{length(messages)} completions of L1-to-L2 messages will be imported")
    end

    import_to_db(messages)

    {:ok, start_block}
  end

  # Constructs a list of `eth_getBlockByNumber` requests for a given list of block numbers.
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

  # Aggregates transactions from a list of blocks, combining them into a single list.
  defp get_transactions(blocks_by_rpc) do
    blocks_by_rpc
    |> Enum.reduce([], fn block_by_rpc, txs ->
      block_by_rpc["transactions"] ++ txs
    end)
  end

  # Imports a list of messages into the database.
  defp import_to_db(messages) do
    {:ok, _} =
      Chain.import(%{
        arbitrum_messages: %{params: messages},
        timeout: :infinity
      })
  end
end
