defmodule Explorer.Chain.SmartContract.JoinBasedQuery do
  @moduledoc """
  Join-based query functions for SmartContract queries.

  This module provides an alternative query strategy using regular joins
  instead of lateral joins. It's used when custom sorting options are provided,
  as the join-based approach works reliably with all sorting combinations.

  For default pagination (sorting by smart_contract.id), the lateral join
  approach in `SmartContract.verified_addresses_query/1` is more efficient.
  """

  import Ecto.Query
  alias Explorer.Chain.{Address, SmartContract}

  @doc """
  Query for verified addresses using join-based filtering.

  This approach uses a regular join between Address and SmartContract tables,
  which works reliably with all sorting options.
  """
  @spec verified_addresses_query(keyword()) :: Ecto.Query.t()
  def verified_addresses_query(options) do
    filter = Keyword.get(options, :filter, nil)
    search_string = Keyword.get(options, :search, nil)

    addresses_query =
      from(
        address in Address,
        join: contract in SmartContract,
        as: :smart_contract,
        on: address.hash == contract.address_hash,
        preload: [:smart_contract]
      )

    addresses_query
    |> filter_contracts_for_join(filter)
    |> search_contracts_for_join(search_string)
  end

  # Applies language filter to the query.
  @spec filter_contracts_for_join(Ecto.Query.t(), atom() | nil) :: Ecto.Query.t()
  defp filter_contracts_for_join(query, nil), do: query

  defp filter_contracts_for_join(query, language) do
    query
    |> where([_address, contract], contract.language == ^language)
  end

  # Applies search filter to the query.
  # Searches in both contract name and address hash fields.
  @spec search_contracts_for_join(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp search_contracts_for_join(query, nil), do: query

  defp search_contracts_for_join(query, search_string) do
    from([_address, contract] in query,
      where:
        ilike(contract.name, ^"%#{search_string}%") or
          ilike(fragment("'0x' || encode(?, 'hex')", contract.address_hash), ^"%#{search_string}%")
    )
  end
end
