defmodule Indexer.Fetcher.ZkSync.StatusTracking.Executed do
  @moduledoc """
    Functionality to discover executed batches
  """

  alias Indexer.Fetcher.ZkSync.Utils.Db
  alias Indexer.Fetcher.ZkSync.Utils.Rpc

  import Indexer.Fetcher.ZkSync.StatusTracking.CommonUtils,
    only: [
      check_if_batch_status_changed: 3,
      prepare_batches_to_import: 2
    ]

  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_info: 1]

  # keccak256("BlockExecution(uint256,bytes32,bytes32)")
  @block_execution_event "0x2402307311a4d6604e4e7b4c8a15a7e1213edb39c16a31efa70afb06030d3165"

  def look_for_batches_and_update(config) do
    case Db.get_earliest_unexecuted_batch_number() do
      nil ->
        :ok

      expected_batch_number ->
        log_info("Checking if the batch #{expected_batch_number} was executed")

        {next_action, tx_hash, l1_txs} = check_if_batch_status_changed(expected_batch_number, :execute_tx, config)

        case next_action do
          :skip ->
            :ok

          :look_for_batches ->
            log_info("The batch #{expected_batch_number} looks like executed")
            execute_tx_receipt = Rpc.fetch_tx_receipt_by_hash(tx_hash, config.json_l1_rpc_named_arguments)
            batches_from_rpc = get_executed_batches_from_logs(execute_tx_receipt["logs"])

            case prepare_batches_to_import(batches_from_rpc, %{execute_id: l1_txs[tx_hash][:id]}) do
              {:error, batches_to_recover} ->
                {:recovery_required, batches_to_recover}

              {:ok, proven_batches} ->
                Db.import_to_db(proven_batches, Map.values(l1_txs))
                :ok
            end
        end
    end
  end

  defp get_executed_batches_from_logs(logs) do
    executed_batches = Rpc.filter_logs_and_extract_topic_at(logs, @block_execution_event, 1)
    log_info("Discovered #{length(executed_batches)} executed batches in the executing tx")

    executed_batches
  end
end
