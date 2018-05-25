defmodule Explorer.Indexer.BlockFetcher.AddressExtraction do
  @moduledoc """
  Extract Addresses from data fetched from the Blockchain and structured as Blocks, InternalTransactions,
  Transactions and Logs.

  Address hashes are present in the Blockchain as a reference of a person that made/received an
  operation in the network. In the POA Explorer it's treated like a entity, such as the ones mentioned
  above.

  This module is responsible for collecting the hashes that are present as attributes in the already
  strucutured entities and structuring them as a list of unique Addresses.

  ## Attributes

  *@entity_to_address_map*

  Defines a rule of where any attributes should be collected `:from` the input and how it should be
  mapped `:to` as a new attribute.

  For example:

      %{
        blocks: [%{from: :miner_hash, to: :hash}],
        # ...
      }

  The structure above means any item in `blocks` list that has a `:miner_hash` attribute should
  be mapped to a `hash` Address attribute.
  """

  @entity_to_address_map %{
    blocks: [%{from: :miner_hash, to: :hash}],
    internal_transactions: [
      %{from: :from_address_hash, to: :hash},
      %{from: :to_address_hash, to: :hash},
      %{from: :created_contract_address_hash, to: :hash}
    ],
    transactions: [
      %{from: :from_address_hash, to: :hash},
      %{from: :to_address_hash, to: :hash}
    ],
    logs: [%{from: :address_hash, to: :hash}]
  }

  def extract_addresses(fetched_data) do
    addresses =
      for {entity_key, entity_fields} <- @entity_to_address_map,
          (entity_items = Map.get(fetched_data, entity_key)) != nil,
          do: extract_addresses_from_collection(entity_items, entity_fields)

    addresses
    |> List.flatten()
    |> Enum.uniq()
  end

  def extract_addresses_from_collection(items, fields),
    do: Enum.flat_map(items, &extract_addresses_from_item(&1, fields))

  def extract_addresses_from_item(item, fields), do: Enum.map(fields, &extract_address(&1, item))

  defp extract_address(%{from: from_attribute, to: to_attribute}, item) do
    if value = Map.get(item, from_attribute) do
      %{to_attribute => value}
    else
      []
    end
  end
end
