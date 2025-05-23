defmodule BlockScoutWeb.API.V2.Helper do
  @moduledoc """
    API V2 helper
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy
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

    proxy_implementations =
      case address.proxy_implementations do
        %NotLoaded{} ->
          nil

        nil ->
          nil

        proxy_implementations ->
          proxy_implementations
      end

    %{
      "hash" => Address.checksum(address),
      "is_contract" => smart_contract?,
      "name" => address_name(address),
      "is_scam" => address_marked_as_scam?(address),
      "proxy_type" => proxy_implementations && proxy_implementations.proxy_type,
      "implementations" => Proxy.proxy_object_info(proxy_implementations),
      "is_verified" => smart_contract_verified?(address) || verified_as_proxy?(proxy_implementations),
      "ens_domain_name" => address.ens_domain_name,
      "metadata" => address.metadata
    }
    |> address_chain_type_fields(address)
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
      "is_scam" => false,
      "proxy_type" => nil,
      "implementations" => [],
      "is_verified" => nil,
      "ens_domain_name" => nil,
      "metadata" => nil
    }
  end

  case @chain_type do
    :filecoin ->
      defp address_chain_type_fields(result, address) do
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        BlockScoutWeb.API.V2.FilecoinView.extend_address_json_response(result, address)
      end

    _ ->
      defp address_chain_type_fields(result, _address) do
        result
      end
  end

  # We treat contracts with minimal proxy or similar standards as verified if all their implementations are verified
  defp verified_as_proxy?(%{proxy_type: proxy_type, names: names})
       when proxy_type in [:eip1167, :eip7702, :clone_with_immutable_arguments, :erc7760] do
    !Enum.empty?(names) && Enum.all?(names)
  end

  defp verified_as_proxy?(_), do: false

  def address_name(%Address{names: [_ | _] = address_names}) do
    case Enum.find(address_names, &(&1.primary == true)) do
      nil ->
        # take last created address name, if there is no `primary` one.
        %Address.Name{name: name} = Enum.max_by(address_names, & &1.id)
        name

      %Address.Name{name: name} ->
        name
    end
  end

  def address_name(_), do: nil

  def address_marked_as_scam?(%Address{scam_badge: %Ecto.Association.NotLoaded{}}) do
    false
  end

  def address_marked_as_scam?(%Address{scam_badge: scam_badge}) when not is_nil(scam_badge) do
    true
  end

  def address_marked_as_scam?(_), do: false

  @doc """
  Determines if a smart contract is verified.

  ## Parameters
    - address: An `%Address{}` struct containing smart contract information.

  ## Returns
    - `false` if the smart contract has metadata from a verified bytecode twin.
    - `false` if the smart contract is `nil`.
    - `false` if the smart contract is `NotLoaded`.
    - `true` if the smart contract is present and does not have metadata from a verified bytecode twin.
  """
  @spec smart_contract_verified?(Address.t()) :: boolean()
  def smart_contract_verified?(%Address{smart_contract: nil}), do: false
  def smart_contract_verified?(%Address{smart_contract: %{metadata_from_verified_bytecode_twin: true}}), do: false
  def smart_contract_verified?(%Address{smart_contract: %NotLoaded{}}), do: nil
  def smart_contract_verified?(%Address{smart_contract: %SmartContract{}}), do: true

  def market_cap(:standard, %{available_supply: available_supply, fiat_value: fiat_value, market_cap: market_cap})
      when is_nil(available_supply) or is_nil(fiat_value) do
    max(Decimal.new(0), market_cap)
  end

  def market_cap(:standard, %{available_supply: available_supply, fiat_value: fiat_value}) do
    Decimal.mult(available_supply, fiat_value)
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
