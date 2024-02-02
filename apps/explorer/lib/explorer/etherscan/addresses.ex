defmodule Explorer.Etherscan.Addresses do
  @moduledoc """
  This module contains functions for working with addresses, as they pertain to the
  `Explorer.Etherscan` context.

  """

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Chain.Address
  alias Explorer.Repo

  @spec list_ordered_addresses(non_neg_integer(), non_neg_integer()) :: [Address.t()]
  def list_ordered_addresses(offset, limit) do
    query =
      from(
        address in Address,
        order_by: [asc: address.inserted_at, asc: address.hash],
        offset: ^offset,
        limit: ^limit
      )

    Repo.replica().all(query)
  end
end
