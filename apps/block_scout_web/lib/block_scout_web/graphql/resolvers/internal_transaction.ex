defmodule BlockScoutWeb.GraphQL.Resolvers.InternalTransaction do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias BlockScoutWeb.Chain
  alias Explorer.Chain.Transaction
  alias Explorer.{GraphQL, PagingOptions, Repo}

  def get_by(%{transaction_hash: transaction_hash, index: index} = args, _) do
    case Chain.hash_to_transaction(transaction_hash) do
      {:ok, transaction} ->
        transaction
        |> Chain.transaction_to_internal_transactions(paging_options: %PagingOptions{key: {index - 1}, page_size: 1})
        |> List.first()

      _ ->
        {:error, "Internal transaction not found."}
    end
  end

  def get_by(%Transaction{} = transaction, args, _) do
    Chain.transaction_to_internal_transactions(transaction, options(args))
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [paging_options: %PagingOptions{page_size: count}]

  defp options(_), do: []
end
