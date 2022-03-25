defmodule Explorer.Celo.CacheHelper do
  def set_test_address(address \\ "0x000000000000000000000000000000000000ce10") do
    Explorer.Celo.AddressCache.Mock |> Mox.stub(:contract_address, fn _name -> address end)

    Explorer.Celo.AddressCache.Mock
    |> Mox.stub(:is_core_contract_address?, fn
      ^address -> true
      _ -> false
    end)
  end

  def set_test_addresses(names_to_addresses = %{}) do
    Explorer.Celo.AddressCache.Mock |> Mox.stub(:contract_address, fn name -> names_to_addresses[name] end)

    Explorer.Celo.AddressCache.Mock
    |> Mox.stub(:is_core_contract_address?, fn address ->
      names_to_addresses |> Map.values() |> Enum.member?(address)
    end)
  end

  def empty_address_cache() do
    Explorer.Celo.AddressCache.Mock |> Mox.stub(:contract_address, fn _name -> :error end)
  end

  def set_cache_address_set() do
    Explorer.Celo.AddressCache.Mock |> Mox.stub(:is_core_contract_address?, fn -> true end)
  end

  def set_cache_address_set(set) do
    Explorer.Celo.AddressCache.Mock
    |> Mox.stub(:is_core_contract_address?, fn address ->
      MapSet.member?(set, address)
    end)
  end
end
