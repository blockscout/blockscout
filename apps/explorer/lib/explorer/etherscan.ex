defmodule Explorer.Etherscan do
  @moduledoc """
  The etherscan context.
  """

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.{Repo, Chain}
  alias Explorer.Chain.{Hash, Transaction}

  @doc """
  Gets a list of transactions for a given `t:Explorer.Chain.Hash.Address`.

  """
  @spec list_transactions(Hash.Address.t()) :: [map()]
  def list_transactions(%Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash) do
    case Chain.max_block_number() do
      {:ok, max_block_number} ->
        list_transactions(address_hash, max_block_number)

      _ ->
        []
    end
  end

  @transaction_fields [
    :block_number,
    :hash,
    :nonce,
    :block_hash,
    :index,
    :from_address_hash,
    :to_address_hash,
    :value,
    :gas,
    :gas_price,
    :status,
    :input,
    :cumulative_gas_used,
    :gas_used
  ]

  defp list_transactions(address_hash, max_block_number) do
    query =
      from(
        t in Transaction,
        inner_join: b in assoc(t, :block),
        left_join: it in assoc(t, :internal_transactions),
        where: t.to_address_hash == ^address_hash,
        or_where: t.from_address_hash == ^address_hash,
        or_where: it.transaction_hash == t.hash and it.type == ^"create",
        order_by: [asc: t.block_number],
        limit: 10_000,
        select:
          merge(map(t, ^@transaction_fields), %{
            block_timestamp: b.timestamp,
            created_contract_address_hash: it.created_contract_address_hash,
            confirmations: fragment("? - ?", ^max_block_number, t.block_number)
          })
      )

    Repo.all(query)
  end
end
