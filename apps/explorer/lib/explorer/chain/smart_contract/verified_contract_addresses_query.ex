defmodule Explorer.Chain.SmartContract.VerifiedContractAddressesQuery do
  @moduledoc """
  Query functions for fetching verified smart-contract addresses.

  This module selects the query strategy based on sorting options:
  - lateral join strategy when no custom sorting is provided
  - join strategy when custom sorting is provided
  """

  import Ecto.Query

  alias Explorer.{Chain, SortingHelper}
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.Helper, as: ExplorerHelper

  @spec list(keyword()) :: [Address.t()]
  def list(options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    sorting = Keyword.get(options, :sorting)

    # If no sorting options are provided, we sort by `:id` descending only. If
    # there are some sorting options supplied, we sort by `:hash` ascending as a
    # secondary key.
    {sorting_options, default_sorting_options} =
      case sorting do
        nil ->
          {[], [{:desc, :id, :smart_contract}]}

        sorting_options ->
          {sorting_options, [asc: :hash]}
      end

    # Use lateral join for default id-based pagination (efficient).
    # Use join-based approach for custom sorting (works reliably with all sorting options).
    addresses_query =
      case sorting do
        nil -> verified_addresses_query_by_lateral(options)
        _ -> verified_addresses_query_by_join(options)
      end

    addresses_query
    |> ExplorerHelper.maybe_hide_scam_addresses_with_select(:hash, options)
    |> SortingHelper.apply_sorting(sorting_options, default_sorting_options)
    |> SortingHelper.page_with_sorting(paging_options, sorting_options, default_sorting_options)
    |> Chain.join_associations(necessity_by_association)
    |> Chain.select_repo(options).all()
  end

  @spec verified_addresses_query_by_lateral(keyword()) :: Ecto.Query.t()
  defp verified_addresses_query_by_lateral(options) do
    filter = Keyword.get(options, :filter)
    search_string = Keyword.get(options, :search)

    smart_contracts_by_address_hash_query =
      from(
        contract in SmartContract,
        where: contract.address_hash == parent_as(:address).hash
      )

    smart_contracts_subquery =
      smart_contracts_by_address_hash_query
      |> filter_contracts(filter, :lateral)
      |> search_contracts(search_string, :lateral)
      |> limit(1)
      |> subquery()

    from(
      address in Address,
      as: :address,
      where: address.verified == true,
      inner_lateral_join: contract in ^smart_contracts_subquery,
      as: :smart_contract,
      on: true,
      select: address,
      preload: [smart_contract: contract]
    )
  end

  @spec verified_addresses_query_by_join(keyword()) :: Ecto.Query.t()
  defp verified_addresses_query_by_join(options) do
    filter = Keyword.get(options, :filter)
    search_string = Keyword.get(options, :search)

    addresses_query =
      from(
        address in Address,
        join: contract in SmartContract,
        as: :smart_contract,
        on: address.hash == contract.address_hash,
        preload: [:smart_contract]
      )

    addresses_query
    |> filter_contracts(filter, :join)
    |> search_contracts(search_string, :join)
  end

  @spec search_contracts(Ecto.Query.t(), String.t() | nil, :lateral | :join) :: Ecto.Query.t()
  defp search_contracts(query, nil, _strategy), do: query

  defp search_contracts(query, search_string, :lateral) do
    from(contract in query,
      where:
        ilike(contract.name, ^"%#{search_string}%") or
          ilike(fragment("'0x' || encode(?, 'hex')", contract.address_hash), ^"%#{search_string}%")
    )
  end

  defp search_contracts(query, search_string, :join) do
    from([_address, contract] in query,
      where:
        ilike(contract.name, ^"%#{search_string}%") or
          ilike(fragment("'0x' || encode(?, 'hex')", contract.address_hash), ^"%#{search_string}%")
    )
  end

  @spec filter_contracts(Ecto.Query.t(), atom() | nil, :lateral | :join) :: Ecto.Query.t()
  defp filter_contracts(query, nil, _strategy), do: query

  defp filter_contracts(query, language, :lateral) do
    query |> where(language: ^language)
  end

  defp filter_contracts(query, language, :join) do
    query |> where([_address, contract], contract.language == ^language)
  end
end
