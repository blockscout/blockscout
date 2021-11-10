defmodule Explorer.Celo.CacheHelper do
  def set_test_address(address \\ "0x000000000000000000000000000000000000ce10") do
    Explorer.Celo.AddressCache.Mock |> Mox.stub(:contract_address, fn _name -> address end)
  end

  def set_test_addresses(names_to_addresses = %{}) do
    Explorer.Celo.AddressCache.Mock |> Mox.stub(:contract_address, fn name -> names_to_addresses[name] end)
  end

  def empty_address_cache() do
    Explorer.Celo.AddressCache.Mock |> Mox.stub(:contract_address, fn _name -> :error end)
  end
end
