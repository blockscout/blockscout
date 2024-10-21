defmodule Indexer.Fetcher.ZkSync.StatusTracking.Executed do
  @moduledoc """
    Functionality to discover executed batches
  """

  alias Indexer.Fetcher.ZkSync.Utils.{Db, Rpc}

  import Indexer.Fetcher.ZkSync.StatusTracking.CommonUtils,
    only: [
      check_if_batch_status_changed: 3,
      associate_and_import_or_prepare_for_recovery: 4
    ]

  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_info: 1]

  # keccak256("BlockExecution(uint256,bytes32,bytes32)")
  @block_execution_event "0x2402307311a4d6604e4e7b4c8a15a7e1213edb39c16a31efa70afb06030d3165"

  @doc """
    Checks if the oldest unexecuted batch in the database has the associated L1 executing transaction
    by requesting new batch details from RPC. If so, analyzes the `BlockExecution` event emitted by
    the transaction to explore all the batches executed by it. For all discovered batches, it updates
    the database with new associations, importing information about L1 transactions.
    If it is found that some of the discovered batches are absent in the database, the function
    interrupts and returns the list of batch numbers that can be attempted to be recovered.

    ## Parameters
    - `config`: Configuration containing `json_l1_rpc_named_arguments` and
                `json_l2_rpc_named_arguments` defining parameters for the RPC connections.

    ## Returns
    - `:ok` if no new executed batches are found, or if all found batches and the corresponding L1
      transactions are imported successfully.
    - `{:recovery_required, batches_to_recover}` if the absence of new executed batches is
      discovered; `batches_to_recover` contains the list of batch numbers.
  """
  @spec look_for_batches_and_update(%{
          :json_l1_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
          :json_l2_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
          optional(any()) => any()
        }) :: :ok | {:recovery_required, list()}
  def look_for_batches_and_update(
        %{
          json_l1_rpc_named_arguments: json_l1_rpc_named_arguments,
          json_l2_rpc_named_arguments: json_l2_rpc_named_arguments
        } = _config
      ) do
    case Db.get_earliest_unexecuted_batch_number() do
      nil ->
        :ok

      expected_batch_number ->
        log_info("Checking if the batch #{expected_batch_number} was executed")

        {next_action, transaction_hash, l1_transactions} =
          check_if_batch_status_changed(expected_batch_number, :execute_transaction, json_l2_rpc_named_arguments)

        case next_action do
          :skip ->
            :ok

          :look_for_batches ->
            log_info("The batch #{expected_batch_number} looks like executed")

            execute_transaction_receipt =
              Rpc.fetch_transaction_receipt_by_hash(transaction_hash, json_l1_rpc_named_arguments)

            batches_numbers_from_rpc = get_executed_batches_from_logs(execute_transaction_receipt["logs"])

            associate_and_import_or_prepare_for_recovery(
              batches_numbers_from_rpc,
              l1_transactions,
              transaction_hash,
              :execute_id
            )
        end
    end
  end

  defp get_executed_batches_from_logs(logs) do
    executed_batches = Rpc.filter_logs_and_extract_topic_at(logs, @block_execution_event, 1)
    log_info("Discovered #{length(executed_batches)} executed batches in the executing transaction")

    executed_batches
  end
end
