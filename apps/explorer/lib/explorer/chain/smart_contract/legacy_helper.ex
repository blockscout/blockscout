defmodule Explorer.Chain.SmartContract.LegacyHelper do
  @moduledoc """
  Legacy functions for SmartContract verification during database migration.

  This module contains legacy query functions that are used as a fallback during
  the migration period when the `language` field is being populated in the
  smart_contracts table. These functions maintain compatibility with
  pre-migration behavior by checking both the new `language` field and the
  legacy boolean flags like `is_vyper_contract`.

  All functions in this module are temporary and will be removed after the
  following migrations are complete:
  - smart_contract_language background migration
  - sanitize_verified_addresses background migration
  - heavy_indexes_create_smart_contracts_language_index migration

  Related to issue: https://github.com/blockscout/blockscout/issues/11822
  """

  import Ecto.Query
  alias Explorer.Chain.{Address, SmartContract}

  @doc """
  Legacy query for verified addresses using join-based filtering.

  This approach is less performant than using lateral joins but is required
  during the migration period when indexes are being created and language fields
  populated.
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

  # Applies language filter to the query with legacy compatibility. Works with
  # join-based queries where contract is the second binding.
  @spec filter_contracts_for_join(Ecto.Query.t(), atom() | nil) :: Ecto.Query.t()
  defp filter_contracts_for_join(query, nil), do: query

  defp filter_contracts_for_join(query, language) do
    query
    |> where([_address, contract], contract.language == ^language)
    |> maybe_filter_contracts_on_legacy_fields_for_join(language)
  end

  # Conditionally applies legacy filtering based on migration status.
  #
  # Checks if the smart_contract_language migration is complete before
  # deciding whether to apply legacy filtering.
  @spec maybe_filter_contracts_on_legacy_fields_for_join(Ecto.Query.t(), atom()) :: Ecto.Query.t()
  defp maybe_filter_contracts_on_legacy_fields_for_join(query, language) do
    alias Explorer.Chain.Cache.BackgroundMigrations

    if BackgroundMigrations.get_smart_contract_language_finished() do
      query
    else
      apply_legacy_language_filter_for_join(query, language)
    end
  end

  # Applies language-specific filtering for legacy fields.
  #
  # This function maintains backward compatibility during migration
  # by checking boolean flags that were previously used to determine
  # contract language before the dedicated field was introduced.
  @spec apply_legacy_language_filter_for_join(Ecto.Query.t(), atom()) :: Ecto.Query.t()
  defp apply_legacy_language_filter_for_join(query, :solidity) do
    query
    |> or_where(
      [_address, contract],
      not contract.is_vyper_contract and not is_nil(contract.abi) and is_nil(contract.language)
    )
  end

  defp apply_legacy_language_filter_for_join(query, :vyper) do
    query |> or_where([_address, contract], contract.is_vyper_contract and is_nil(contract.language))
  end

  defp apply_legacy_language_filter_for_join(query, :yul) do
    query |> or_where([_address, contract], is_nil(contract.abi) and is_nil(contract.language))
  end

  defp apply_legacy_language_filter_for_join(query, _), do: query

  # Applies search filter to the query with join-based approach.
  #
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
