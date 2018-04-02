defmodule Explorer.Transaction.Service do
  @moduledoc "Service module for interacting with Transactions"

  alias Explorer.InternalTransaction
  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction.Service.Query

  def internal_transactions(hash) do
    InternalTransaction
    |> Query.for_parent_transaction(hash)
    |> Query.join_from_and_to_addresses()
    |> Repo.all()
  end

  defmodule Query do
    @moduledoc "Helper module to hold Transaction-related query fragments"

    import Ecto.Query, only: [from: 2]

    def to_address(query, to_address_id) do
      from(q in query, where: q.to_address_id == ^to_address_id)
    end

    def from_address(query, from_address_id) do
      from(q in query, where: q.from_address_id == ^from_address_id)
    end

    def recently_seen(query, last_seen) do
      from(
        q in query,
        where: q.id < ^last_seen,
        order_by: [desc: q.id],
        limit: 10
      )
    end

    def by_hash(query, hash) do
      from(
        q in query,
        where: fragment("lower(?)", q.hash) == ^String.downcase(hash),
        limit: 1
      )
    end

    def include_addresses(query) do
      from(
        q in query,
        inner_join: to_address in assoc(q, :to_address),
        inner_join: from_address in assoc(q, :from_address),
        preload: [
          to_address: to_address,
          from_address: from_address
        ]
      )
    end

    def include_receipt(query) do
      from(
        q in query,
        left_join: receipt in assoc(q, :receipt),
        preload: [
          receipt: receipt
        ]
      )
    end

    def include_block(query) do
      from(
        q in query,
        left_join: block in assoc(q, :block),
        preload: [
          block: block
        ]
      )
    end

    def require_receipt(query) do
      from(
        q in query,
        inner_join: receipt in assoc(q, :receipt),
        preload: [
          receipt: receipt
        ]
      )
    end

    def require_block(query) do
      from(
        q in query,
        inner_join: block in assoc(q, :block),
        preload: [
          block: block
        ]
      )
    end

    def for_parent_transaction(query, hash) do
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

    def chron(query) do
      from(q in query, order_by: [desc: q.inserted_at])
    end
  end
end
