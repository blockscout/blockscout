# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.PendingTransactionsSanitizer do
  @moduledoc """
  Periodically checks pending transactions status in order to detect that transaction already included to the block
  And we need to re-fetch that block.

  Pending transactions are processed page by page, so the memory used by a run
  doesn't depend on the number of pending transactions in the DB.
  """

  use GenServer

  require Logger

  import Ecto.Query, only: [from: 2]
  import EthereumJSONRPC, only: [json_rpc: 2, request: 1, id_to_params: 1]
  import EthereumJSONRPC.Receipt, only: [to_elixir: 1]

  alias Ecto.Changeset
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Repo

  defstruct interval: nil,
            json_rpc_named_arguments: []

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments}
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(init_opts, gen_server_opts \\ []) do
    GenServer.start_link(__MODULE__, init_opts, Keyword.put_new(gen_server_opts, :name, __MODULE__))
  end

  def init(opts) when is_list(opts) do
    state = %__MODULE__{
      json_rpc_named_arguments: Keyword.fetch!(opts, :json_rpc_named_arguments),
      interval: Application.get_env(:indexer, __MODULE__)[:interval]
    }

    Process.send_after(self(), :sanitize_pending_transactions, state.interval)

    {:ok, state}
  end

  def handle_info(
        :sanitize_pending_transactions,
        %{interval: interval, json_rpc_named_arguments: json_rpc_named_arguments} = state
      ) do
    Logger.debug("Start sanitizing of pending transactions",
      fetcher: :pending_transactions_to_refetch
    )

    sanitize_pending_transactions(json_rpc_named_arguments)

    Process.send_after(self(), :sanitize_pending_transactions, interval)

    {:noreply, state, :hibernate}
  end

  @doc """
  Fetches the receipts of the pending transactions that are older than the configured
  `:window_size` when the call starts, one page of `receipts_batch_size` transactions at a time.

  Deletes the transactions the node doesn't know anymore. Updates the transactions
  included into a block stored in the DB from their receipts, and marks that block
  for refetch if it is a consensus one.
  """
  @spec sanitize_pending_transactions(EthereumJSONRPC.json_rpc_named_arguments()) :: :ok
  def sanitize_pending_transactions(json_rpc_named_arguments) do
    page_size = Application.get_env(:indexer, :receipts_batch_size)
    window_size = Application.get_env(:indexer, __MODULE__)[:window_size]

    # The cutoff is fixed for the whole run, so the run goes over a finite set of transactions
    # and ends. The transactions that become stale during the run are left to the next run.
    inserted_before = DateTime.add(DateTime.utc_now(), -window_size, :millisecond)

    sanitize_pages(nil, page_size, inserted_before, json_rpc_named_arguments)

    Logger.debug("Pending transactions are sanitized",
      fetcher: :pending_transactions_to_refetch
    )
  end

  defp sanitize_pages(last_key, page_size, inserted_before, json_rpc_named_arguments) do
    pending_transactions = Transaction.stale_pending_transactions_page(inserted_before, page_size, last_key)

    sanitize_page(pending_transactions, page_size, json_rpc_named_arguments)

    # The next page starts after the key of the last transaction of this page,
    # so the transactions deleted or updated above don't shift it.
    if length(pending_transactions) == page_size do
      %{inserted_at: inserted_at, hash: hash} = List.last(pending_transactions)
      sanitize_pages({inserted_at, hash}, page_size, inserted_before, json_rpc_named_arguments)
    end
  end

  defp sanitize_page([], _page_size, _json_rpc_named_arguments), do: :ok

  defp sanitize_page(pending_transactions, page_size, json_rpc_named_arguments) do
    id_to_hash =
      pending_transactions
      |> Enum.map(& &1.hash)
      |> id_to_params()

    # The page size is `receipts_batch_size`, so the requests of a page make a single chunk.
    chunked_requests =
      id_to_hash
      |> get_transaction_receipt_requests()
      |> Enum.chunk_every(page_size)

    case json_rpc(chunked_requests, json_rpc_named_arguments) do
      {:ok, responses} ->
        handle_responses(responses, id_to_hash)

      {:error, reason} ->
        Logger.error("Error while fetching pending transaction receipts: #{inspect(reason)}",
          fetcher: :pending_transactions_to_refetch
        )
    end
  end

  defp get_transaction_receipt_requests(id_to_hash) do
    Enum.map(id_to_hash, fn {id, hash} ->
      request(%{id: id, method: "eth_getTransactionReceipt", params: [to_string(hash)]})
    end)
  end

  defp handle_responses(responses, id_to_hash) do
    {not_found_hashes, included_transactions} =
      Enum.reduce(responses, {[], []}, fn
        %{id: id, result: nil}, {not_found_hashes, included_transactions} ->
          {[Map.fetch!(id_to_hash, id) | not_found_hashes], included_transactions}

        %{id: id, result: %{"blockHash" => block_hash} = receipt}, {not_found_hashes, included_transactions}
        when not is_nil(block_hash) ->
          {not_found_hashes, [{Map.fetch!(id_to_hash, id), receipt} | included_transactions]}

        %{id: id, result: _receipt}, acc ->
          Logger.debug(
            "Transaction with hash #{Map.fetch!(id_to_hash, id)} is still pending. Do nothing.",
            fetcher: :pending_transactions_to_refetch
          )

          acc

        error, acc ->
          Logger.error("Error while fetching pending transaction receipt: #{inspect(error)}")

          acc
      end)

    delete_pending_transactions(not_found_hashes)

    Enum.each(included_transactions, fn {hash, receipt} -> fetch_block_and_invalidate(hash, receipt) end)
  end

  defp delete_pending_transactions([]), do: :ok

  defp delete_pending_transactions(hashes) do
    # The transactions included into a block since the receipts were fetched are not deleted.
    locked_query =
      from(
        transaction in Transaction,
        where: transaction.hash in ^hashes and is_nil(transaction.block_hash),
        select: map(transaction, [:hash]),
        # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: transaction.hash],
        lock: "FOR UPDATE"
      )

    {deleted_count, _} =
      Repo.delete_all(
        from(
          transaction in Transaction,
          join: locked in subquery(locked_query),
          on: transaction.hash == locked.hash
        ),
        timeout: :infinity
      )

    Logger.debug(
      "#{deleted_count} of #{length(hashes)} pending transactions are deleted from Blockscout DB because they don't exist in the node anymore",
      fetcher: :pending_transactions_to_refetch
    )
  end

  defp fetch_block_and_invalidate(hash, %{"blockHash" => block_hash} = receipt) do
    Logger.debug(
      "Transaction with hash #{hash} already included into the block #{block_hash}. We should invalidate consensus for it in order to re-fetch transactions",
      fetcher: :pending_transactions_to_refetch
    )

    case Block.fetch_block_by_hash(block_hash) do
      %{number: number, consensus: consensus} = block ->
        Logger.debug(
          "Corresponding number of the block with hash #{block_hash} to invalidate is #{number} and consensus #{consensus}",
          fetcher: :pending_transactions_to_refetch
        )

        invalidate_block_if_pending(block, hash, receipt)

      _ ->
        Logger.debug(
          "Block with hash #{block_hash} is not yet in the DB",
          fetcher: :pending_transactions_to_refetch
        )
    end
  end

  # The full transaction is loaded only here, since `Transaction.changeset/2`
  # validates its required fields.
  defp invalidate_block_if_pending(block, hash, receipt) do
    case Repo.get(Transaction, hash) do
      %Transaction{block_hash: nil} = pending_transaction ->
        invalidate_block(block, pending_transaction, receipt)

      _ ->
        Logger.debug(
          "Transaction with hash #{hash} is not pending anymore, cancel update",
          fetcher: :pending_transactions_to_refetch
        )
    end
  end

  defp invalidate_block(block, pending_transaction, transaction) do
    transaction_info = to_elixir(transaction)

    pending_transaction
    |> Transaction.changeset(%{
      gas_price: transaction_info["effectiveGasPrice"] || pending_transaction.gas_price,
      created_contract_address_hash: transaction_info["contractAddress"]
    })
    |> Changeset.put_change(:cumulative_gas_used, transaction_info["cumulativeGasUsed"])
    |> Changeset.put_change(:gas_used, transaction_info["gasUsed"])
    |> Changeset.put_change(:index, transaction_info["transactionIndex"])
    |> Changeset.put_change(:status, transaction_info["status"])
    |> Changeset.put_change(:block_number, block.number)
    |> Changeset.put_change(:block_hash, block.hash)
    |> Changeset.put_change(:block_timestamp, block.timestamp)
    |> Changeset.put_change(:block_consensus, block.consensus)
    |> Repo.update()
    |> case do
      {:ok, _result} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to update pending transaction with hash #{pending_transaction.hash}: #{inspect(error)}")
    end

    if block.consensus do
      Block.set_refetch_needed(block.number)
    else
      Logger.debug(
        "Pending transaction with hash #{pending_transaction.hash} assigned to block ##{block.number} with hash #{block.hash}"
      )
    end
  end
end
