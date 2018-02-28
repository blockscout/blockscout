defmodule Explorer.Address.Service do
  @moduledoc "Service module for interacting with Addresses"

  alias Explorer.Address
  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Address.Service.Query

  def by_hash(hash) do
    Address
    |> Query.by_hash(hash)
    |> Query.include_credit_and_debit()
    |> Repo.one()
  end

  def update_balance(balance, hash) do
    changes = %{
      balance: balance
    }

    hash
    |> find_or_create_by_hash()
    |> Address.balance_changeset(changes)
    |> Repo.update()
  end

  def find_or_create_by_hash(hash) do
    Address
    |> Query.by_hash(hash)
    |> Repo.one()
    |> case do
      nil -> Repo.insert!(Address.changeset(%Address{}, %{hash: hash}))
      address -> address
    end
  end

  defmodule Query do
    @moduledoc "Query module for pulling in aspects of Addresses."

    import Ecto.Query, only: [from: 2]

    def by_hash(query, hash) do
      from(
        q in query,
        where: fragment("lower(?)", q.hash) == ^String.downcase(hash),
        limit: 1
      )
    end

    def include_credit_and_debit(query) do
      from(
        q in query,
        left_join: credit in assoc(q, :credit),
        left_join: debit in assoc(q, :debit),
        preload: [:credit, :debit]
      )
    end
  end
end
