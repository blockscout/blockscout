defmodule Explorer.GraphQL do
  @moduledoc """
  The GraphQL context.
  """

  import Ecto.Query,
    only: [
      order_by: 3,
      or_where: 3,
      where: 3
    ]

  alias Explorer.Chain.{Address, Hash, Transaction}

  def address_to_transactions_query(%Address{hash: %Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash}) do
    Transaction
    |> order_by([transaction], desc: transaction.block_number, desc: transaction.index)
    |> where([transaction], transaction.to_address_hash == ^address_hash)
    |> or_where([transaction], transaction.from_address_hash == ^address_hash)
    |> or_where([transaction], transaction.created_contract_address_hash == ^address_hash)
  end
end
