defmodule BlockScoutWeb.API.V2.Helper do
  @moduledoc """
    API V2 helper
  """

  alias Ecto.Association.NotLoaded
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.Transaction.History.TransactionStats

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 3]

  def address_with_info(conn, address, address_hash, tags_needed?, watchlist_names_cached \\ nil)

  def address_with_info(_, _, nil, _, _) do
    nil
  end

  def address_with_info(conn, address, address_hash, true, nil) do
    %{
      common_tags: public_tags,
      personal_tags: private_tags,
      watchlist_names: watchlist_names
    } = get_address_tags(address_hash, current_user(conn), api?: true)

    Map.merge(address_with_info(address, address_hash), %{
      "private_tags" => private_tags,
      "watchlist_names" => watchlist_names,
      "public_tags" => public_tags
    })
  end

  def address_with_info(_conn, address, address_hash, false, nil) do
    Map.merge(address_with_info(address, address_hash), %{
      "private_tags" => [],
      "watchlist_names" => [],
      "public_tags" => []
    })
  end

  def address_with_info(_conn, address, address_hash, _, watchlist_names_cached) do
    watchlist_name = watchlist_names_cached[address_hash]

    Map.merge(address_with_info(address, address_hash), %{
      "private_tags" => [],
      "watchlist_names" => if(watchlist_name, do: [watchlist_name], else: []),
      "public_tags" => []
    })
  end

  @doc """
  Gets address with the additional info for api v2
  """
  @spec address_with_info(any(), any()) :: nil | %{optional(String.t()) => any()}
  def address_with_info(
        %Address{proxy_implementations: %NotLoaded{}, contract_code: contract_code} = _address,
        _address_hash
      )
      when not is_nil(contract_code) do
    raise "proxy_implementations is not loaded for address"
  end

  def address_with_info(%Address{} = address, _address_hash) do
    smart_contract? = Address.smart_contract?(address)

    {proxy_implementations, implementation_address_hashes, implementation_names} =
      case address.proxy_implementations do
        %NotLoaded{} ->
          {nil, [], []}

        nil ->
          {nil, [], []}

        proxy_implementations ->
          address_hashes = proxy_implementations.address_hashes
          names = proxy_implementations.names

          {proxy_implementations, address_hashes, names}
      end

    %{
      "hash" => Address.checksum(address),
      "is_contract" => smart_contract?,
      "name" => address_name(address),
      "implementations" => proxy_object_info(implementation_address_hashes, implementation_names),
      "is_verified" => verified?(address) || verified_minimal_proxy?(proxy_implementations),
      "ens_domain_name" => address.ens_domain_name,
      "metadata" => address.metadata
    }
  end

  def address_with_info(%NotLoaded{}, address_hash) do
    address_with_info(nil, address_hash)
  end

  def address_with_info(address_info, address_hash) when is_map(address_info) do
    nil
    |> address_with_info(address_hash)
    |> Map.put("ens_domain_name", address_info[:ens_domain_name])
    |> Map.put("metadata", address_info[:metadata])
  end

  def address_with_info(nil, nil) do
    nil
  end

  def address_with_info(_, address_hash) do
    %{
      "hash" => Address.checksum(address_hash),
      "is_contract" => false,
      "name" => nil,
      "implementations" => [],
      "is_verified" => nil,
      "ens_domain_name" => nil,
      "metadata" => nil
    }
  end

  @doc """
  Retrieves formatted proxy object based on its implementation addresses and names.

  ## Parameters

    * `implementation_addresses` - A list of implementation addresses for the proxy object.
    * `implementation_names` - A list of implementation names for the proxy object.

  ## Returns

  A list of maps containing information about the proxy object.

  """
  @spec proxy_object_info([String.t() | Hash.Address.t()], [String.t() | nil]) :: [map()]
  def proxy_object_info([], []), do: []

  def proxy_object_info(implementation_addresses, implementation_names) do
    implementation_addresses
    |> Enum.zip(implementation_names)
    |> Enum.reduce([], fn {address, name}, acc ->
      case address do
        %Hash{} = address_hash ->
          [%{"address" => Address.checksum(address_hash), "name" => name} | acc]

        _ ->
          with {:ok, address_hash} <- Chain.string_to_address_hash(address),
               checksummed_address <- Address.checksum(address_hash) do
            [%{"address" => checksummed_address, "name" => name} | acc]
          else
            _ -> acc
          end
      end
    end)
  end

  defp minimal_proxy_pattern?(proxy_implementations) do
    proxy_implementations.proxy_type == :eip1167
  end

  defp verified_minimal_proxy?(nil), do: false

  defp verified_minimal_proxy?(proxy_implementations) do
    (minimal_proxy_pattern?(proxy_implementations) &&
       Enum.any?(proxy_implementations.names, fn name -> !is_nil(name) end)) || false
  end

  def address_name(%Address{names: [_ | _] = address_names}) do
    case Enum.find(address_names, &(&1.primary == true)) do
      nil ->
        %Address.Name{name: name} = Enum.at(address_names, 0)
        name

      %Address.Name{name: name} ->
        name
    end
  end

  def address_name(_), do: nil

  def verified?(%Address{smart_contract: nil}), do: false
  def verified?(%Address{smart_contract: %{metadata_from_verified_bytecode_twin: true}}), do: false
  def verified?(%Address{smart_contract: %NotLoaded{}}), do: nil
  def verified?(%Address{smart_contract: _}), do: true

  def market_cap(:standard, %{available_supply: available_supply, usd_value: usd_value, market_cap_usd: market_cap_usd})
      when is_nil(available_supply) or is_nil(usd_value) do
    max(Decimal.new(0), market_cap_usd)
  end

  def market_cap(:standard, %{available_supply: available_supply, usd_value: usd_value}) do
    Decimal.mult(available_supply, usd_value)
  end

  def market_cap(module, exchange_rate) do
    module.market_cap(exchange_rate)
  end

  def get_transaction_stats do
    stats_scale = date_range(1)
    transaction_stats = TransactionStats.by_date_range(stats_scale.earliest, stats_scale.latest)

    # Need datapoint for legend if none currently available.
    if Enum.empty?(transaction_stats) do
      [%{number_of_transactions: 0, gas_used: 0}]
    else
      transaction_stats
    end
  end

  def date_range(num_days) do
    today = Date.utc_today()
    latest = Date.add(today, -1)
    x_days_back = Date.add(latest, -1 * (num_days - 1))
    %{earliest: x_days_back, latest: latest}
  end

  @doc """
    Checks if an item associated with a DB entity has actual value

    ## Parameters
    - `associated_item`: an item associated with a DB entity

    ## Returns
    - `false`: if the item is nil or not loaded
    - `true`: if the item has actual value
  """
  @spec specified?(any()) :: boolean()
  def specified?(associated_item) do
    case associated_item do
      nil -> false
      %Ecto.Association.NotLoaded{} -> false
      _ -> true
    end
  end

  @doc """
    Gets the value of an element nested in a map using two keys.

    Clarification: Returns `map[key1][key2]`

    ## Parameters
    - `map`: The high-level map.
    - `key1`: The key of the element in `map`.
    - `key2`: The key of the element in the map accessible by `map[key1]`.

    ## Returns
    The value of the element, or `nil` if the map accessible by `key1` does not exist.
  """
  @spec get_2map_data(map(), any(), any()) :: any()
  def get_2map_data(map, key1, key2) do
    case Map.get(map, key1) do
      nil -> nil
      inner_map -> Map.get(inner_map, key2)
    end
  end
end
