defmodule BlockScoutWeb.GraphQL.Resolvers.InternalTransaction do
  @moduledoc false

  import Explorer.Chain, only: [hash_to_transaction: 1]

  alias Absinthe.Relay.Connection
  alias BlockScoutWeb.Chain
  alias Explorer.Chain.{InternalTransaction, Transaction}
  alias Explorer.{GraphQL, PagingOptions}
  alias Indexer.Fetcher.OnDemand.InternalTransaction, as: InternalTransactionOnDemand

  def get_by(%{transaction_hash: transaction_hash, index: index} = args, _) do
    case hash_to_transaction(transaction_hash) do
      {:ok, transaction} ->
        if InternalTransaction.present_in_db?(transaction.block_number) do
          GraphQL.get_internal_transaction(args)
        else
          options = [paging_options: %PagingOptions{page_size: index + 1}]

          transaction
          |> InternalTransactionOnDemand.fetch_by_transaction(options)
          |> Enum.find(&(&1.index == index))
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          |> case do
            nil -> {:error, "Internal transaction not found."}
            internal_transaction -> {:ok, internal_transaction}
          end
        end

      _ ->
        {:error, "Internal transaction not found."}
    end
  end

  def get_by(%Transaction{} = transaction, args, _) do
    transaction
    |> Chain.transaction_to_internal_transactions(options(args))
    |> Connection.from_list(args, options(args))
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [paging_options: %PagingOptions{page_size: count}]

  defp options(_), do: []
end
