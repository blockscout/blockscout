defmodule Indexer.Fetcher.Arbitrum.Workers.HistoricalMessagesOnL2 do
  @moduledoc """
  Handles the discovery and processing of historical messages between Layer 1 (L1)  and Layer 2 (L2) within an Arbitrum rollup.

  ## L1-to-L2 Messages
  L1-to-L2 messages are discovered by first inspecting the database to identify
  potentially missed messages. Then, rollup transactions are requested through RPC
  to fetch the necessary data. This is required because some Arbitrum-specific fields,
  such as the `requestId`, are not included in the already indexed transactions within
  the database.

  ## L2-to-L1 Messages
  L2-to-L1 messages are discovered by analyzing the logs of already indexed rollup
  transactions.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1, log_info: 1, log_debug: 1]

  alias EthereumJSONRPC.Transaction, as: TransactionByRPC

  alias Explorer.Chain

  alias Indexer.Fetcher.Arbitrum.Messaging
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Rpc}

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
      If `nil` or less than the indexer's first block, the function returns with no
      action taken.
    - `state`: Contains the operational configuration, including the depth of
      blocks to consider for the starting point of message discovery and the
      first block of the rollup chain.

    ## Returns
    - `{:ok, nil}`: If `end_block` is `nil`, indicating no discovery action was
      required.
    - `{:ok, rollup_first_block}`: If `end_block` is less than the indexer's first
      block, indicating that the "genesis" of the blockchain was reached.
    - `{:ok, start_block}`: Upon successful discovery of historical messages, where
      `start_block` indicates the necessity to consider another block range in the
      next iteration of message discovery.
    - `{:ok, end_block + 1}`: If the required block range is not fully indexed,
      indicating that the next iteration of message discovery should start with the
      same block range.
  """
  @spec discover_historical_messages_from_l2(nil | integer(), %{
          :config => %{
            :missed_messages_blocks_depth => non_neg_integer(),
            :rollup_rpc => %{
              :first_block => non_neg_integer(),
              optional(any()) => any()
            },
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
            missed_messages_blocks_depth: missed_messages_blocks_depth,
            rollup_rpc: %{first_block: rollup_first_block}
          }
        } = _state
      )
      when is_integer(end_block) do
    start_block = max(rollup_first_block, end_block - missed_messages_blocks_depth + 1)

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
  #   starting block number.
  @spec do_discover_historical_messages_from_l2(non_neg_integer(), non_neg_integer()) :: {:ok, non_neg_integer()}
  defp do_discover_historical_messages_from_l2(start_block, end_block) do
    log_info("Block range for discovery historical messages from L2: #{start_block}..#{end_block}")

    logs = Db.logs_for_missed_messages_from_l2(start_block, end_block)

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

    This function orchestrates the process of discovering historical L1-to-L2
    messages within a given rollup block range, based on the existence of the
    `requestId` field in the rollup transaction body. The initial list of
    transactions that could contain the messages is received from the database, and
    then their bodies are re-requested through RPC because already indexed
    transactions from the database cannot be utilized; the `requestId` field is not
    included in the transaction model. The function ensures that the block range
    has been indexed before proceeding with message discovery and import. The
    imported messages are marked as `:relayed`, as they represent completed actions
    from L1 to L2.

    ## Parameters
    - `end_block`: The ending block number for the discovery operation. If `nil` or
      less than the indexer's first block, the function returns with no action
      taken.
    - `state`: The current state of the operation, containing configuration
      parameters including the depth of blocks to consider for the starting point
      of message discovery, size of chunk to make request to RPC, and JSON RPC
      connection settings.

    ## Returns
    - `{:ok, nil}`: If `end_block` is `nil`, indicating no action was necessary.
    - `{:ok, rollup_first_block}`: If `end_block` is less than the indexer's first
      block, indicating that the "genesis" of the blockchain was reached.
    - `{:ok, start_block}`: On successful completion of historical message
      discovery, where `start_block` indicates the necessity to consider another
      block range in the next iteration of message discovery.
    - `{:ok, end_block + 1}`: If the required block range is not fully indexed,
      indicating that the next iteration of message discovery should start with the
      same block range.
  """
  @spec discover_historical_messages_to_l2(nil | integer(), %{
          :config => %{
            :missed_messages_blocks_depth => non_neg_integer(),
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
        %{config: %{missed_messages_blocks_depth: _, rollup_rpc: %{first_block: _}} = config} = _state
      )
      when is_integer(end_block) do
    start_block = max(config.rollup_rpc.first_block, end_block - config.missed_messages_blocks_depth + 1)

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

  # Discovers and processes historical messages sent from L1 to L2 within a
  # specified rollup block range.
  #
  # This function identifies which of already indexed transactions within the
  # block range contains L1-to-L2 messages and makes RPC calls to fetch
  # transaction data. These transactions are then processed to construct proper
  # message structures, which are imported into the database. The imported
  # messages are marked as `:relayed` as they represent completed actions from L1
  # to L2.
  #
  # Note: Already indexed transactions from the database cannot be used because
  # the `requestId` field is not included in the transaction model.
  #
  # ## Parameters
  # - `start_block`: The starting block number for the discovery range.
  # - `end_block`: The ending block number for the discovery range.
  # - `config`: The configuration map containing settings for RPC communication
  #   and chunk size.
  #
  # ## Returns
  # - `{:ok, start_block}`: A tuple indicating successful processing, returning
  #                         the initial starting block number.
  @spec do_discover_historical_messages_to_l2(non_neg_integer(), non_neg_integer(), %{
          :rollup_rpc => %{
            :chunk_size => non_neg_integer(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: {:ok, non_neg_integer()}
  defp do_discover_historical_messages_to_l2(
         start_block,
         end_block,
         %{rollup_rpc: %{chunk_size: chunk_size, json_rpc_named_arguments: json_rpc_named_arguments}} = _config
       ) do
    log_info("Block range for discovery historical messages to L2: #{start_block}..#{end_block}")

    transactions = Db.transactions_for_missed_messages_to_l2(start_block, end_block)
    transactions_length = length(transactions)

    if transactions_length > 0 do
      log_debug("#{transactions_length} historical messages to L2 discovered")

      messages =
        transactions
        |> Enum.chunk_every(chunk_size)
        |> Enum.reduce([], fn chunk, messages_acc ->
          # Since DB does not contain the field RequestId specific to Arbitrum
          # all transactions will be requested from the rollup RPC endpoint.
          # The catchup process intended to be run once and only for the BS instance
          # which are already exist, so it does not make sense to introduce
          # the new field in DB
          requests = build_transaction_requests(chunk)

          messages =
            requests
            |> Rpc.make_chunked_request(json_rpc_named_arguments, "eth_getTransactionByHash")
            |> Enum.map(&transaction_json_to_map/1)
            |> Messaging.filter_l1_to_l2_messages(false)

          messages ++ messages_acc
        end)

      # Logging of zero messages is left by intent to reveal potential cases when
      # not all transactions are recognized as completed L1-to-L2 messages.
      log_info("#{length(messages)} completions of L1-to-L2 messages will be imported")
      import_to_db(messages)
    end

    {:ok, start_block}
  end

  # Constructs a list of `eth_getTransactionByHash` requests for a given list of transaction hashes.
  defp build_transaction_requests(tx_hashes) do
    tx_hashes
    |> Enum.reduce([], fn tx_hash, requests_list ->
      [
        Rpc.transaction_by_hash_request(%{id: 0, hash: tx_hash})
        | requests_list
      ]
    end)
  end

  # Transforms a JSON transaction object into a map.
  @spec transaction_json_to_map(%{String.t() => any()}) :: map()
  defp transaction_json_to_map(transaction_json) do
    transaction_json
    |> TransactionByRPC.to_elixir()
    |> TransactionByRPC.elixir_to_params()
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
