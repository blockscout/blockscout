defmodule Indexer.Fetcher.ZkSync.StatusTracking.Proven do
  @moduledoc """
    Functionality to discover proven batches
  """

  alias Indexer.Fetcher.ZkSync.Utils.{Db, Rpc}

  import Indexer.Fetcher.ZkSync.StatusTracking.CommonUtils,
    only: [
      check_if_batch_status_changed: 3,
      associate_and_import_or_prepare_for_recovery: 4
    ]

  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_info: 1]

  @doc """
    Checks if the oldest unproven batch in the database has the associated L1 proving transaction
    by requesting new batch details from RPC. If so, analyzes the calldata of the transaction
    to explore all the batches proven by it. For all discovered batches, it updates
    the database with new associations, importing information about L1 transactions.
    If it is found that some of the discovered batches are absent in the database, the function
    interrupts and returns the list of batch numbers that can be attempted to be recovered.

    ## Parameters
    - `config`: Configuration containing `json_l1_rpc_named_arguments` and
                `json_l2_rpc_named_arguments` defining parameters for the RPC connections.

    ## Returns
    - `:ok` if no new proven batches are found, or if all found batches and the corresponding L1
      transactions are imported successfully.
    - `{:recovery_required, batches_to_recover}` if the absence of new proven batches is
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
    case Db.get_earliest_unproven_batch_number() do
      nil ->
        :ok

      expected_batch_number ->
        log_info("Checking if the batch #{expected_batch_number} was proven")

        {next_action, transaction_hash, l1_transactions} =
          check_if_batch_status_changed(expected_batch_number, :prove_transaction, json_l2_rpc_named_arguments)

        case next_action do
          :skip ->
            :ok

          :look_for_batches ->
            log_info("The batch #{expected_batch_number} looks like proven")
            prove_transaction = Rpc.fetch_transaction_by_hash(transaction_hash, json_l1_rpc_named_arguments)
            batches_numbers_from_rpc = Rpc.get_proven_batches_from_calldata(prove_transaction["input"])

            associate_and_import_or_prepare_for_recovery(
              batches_numbers_from_rpc,
              l1_transactions,
              transaction_hash,
              :prove_id
            )
        end
    end
  end
end
