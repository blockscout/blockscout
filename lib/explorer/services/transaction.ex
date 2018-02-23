defmodule Explorer.Transaction.Service do
  @moduledoc "Service module for interacting with Transactions"

  alias Explorer.InternalTransaction
  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction.Service.Query

  def internal_transactions(hash) do
    InternalTransaction
    |> Query.for_transaction(hash)
    |> Query.join_from_and_to_addresses()
    |> Repo.all()
  end

  defmodule Query do
    @moduledoc "Helper module to hold Transaction-related query fragments"

    import Ecto.Query, only: [from: 2]

    def for_transaction(query, hash) do
      from(
        child in query,
        inner_join: transaction in assoc(child, :transaction),
        where: fragment("lower(?)", transaction.hash) == ^String.downcase(hash)
      )
    end

    def join_from_and_to_addresses(query) do
      from(
        q in query,
        inner_join: to_address in assoc(q, :to_address),
        inner_join: from_address in assoc(q, :from_address),
        preload: [:to_address, :from_address]
      )
    end
  end
end
