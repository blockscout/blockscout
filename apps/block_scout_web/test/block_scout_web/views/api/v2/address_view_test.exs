defmodule BlockScoutWeb.API.V2.AddressViewTest do
  use BlockScoutWeb.ConnCase, async: true

  import Mox

  alias BlockScoutWeb.API.V2.AddressView
  alias Explorer.Repo

  test "for a proxy contract has_methods_read_proxy is true" do
    implementation_address = insert(:contract_address)
    proxy_address = insert(:contract_address) |> Repo.preload([:token])

    _proxy_smart_contract =
      insert(:smart_contract,
        address_hash: proxy_address.hash,
        contract_code_md5: "123",
        implementation_address_hash: implementation_address.hash
      )

    get_eip1967_implementation_zero_addresses()

    assert AddressView.prepare_address(proxy_address)["has_methods_read_proxy"] == true
  end

  def get_eip1967_implementation_zero_addresses do
    EthereumJSONRPC.Mox
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
  end
end
