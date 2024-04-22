defmodule Explorer.TestHelper do
  @moduledoc false

  import Mox

  def mock_logic_storage_pointer_request(
        mox,
        resp \\ "0x0000000000000000000000000000000000000000000000000000000000000000"
      ) do
    expect(mox, :json_rpc, fn %{
                                id: 0,
                                method: "eth_getStorageAt",
                                params: [
                                  _,
                                  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                  "latest"
                                ]
                              },
                              _options ->
      {:ok, resp}
    end)
  end

  def mock_beacon_storage_pointer_request(
        mox,
        resp \\ "0x0000000000000000000000000000000000000000000000000000000000000000"
      ) do
    expect(mox, :json_rpc, fn %{
                                id: 0,
                                method: "eth_getStorageAt",
                                params: [
                                  _,
                                  "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
                                  "latest"
                                ]
                              },
                              _options ->
      {:ok, resp}
    end)
  end

  def mock_eip_1822_storage_pointer_request(
        mox,
        resp \\ "0x0000000000000000000000000000000000000000000000000000000000000000"
      ) do
    expect(mox, :json_rpc, fn %{
                                id: 0,
                                method: "eth_getStorageAt",
                                params: [
                                  _,
                                  "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7",
                                  "latest"
                                ]
                              },
                              _options ->
      {:ok, resp}
    end)
  end

  def mock_oz_storage_pointer_request(
        mox,
        resp \\ "0x0000000000000000000000000000000000000000000000000000000000000000"
      ) do
    expect(mox, :json_rpc, fn %{
                                id: 0,
                                method: "eth_getStorageAt",
                                params: [
                                  _,
                                  "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3",
                                  "latest"
                                ]
                              },
                              _options ->
      {:ok, resp}
    end)
  end

  def get_eip1967_implementation_non_zero_address do
    EthereumJSONRPC.Mox
    |> mock_logic_storage_pointer_request()
    |> mock_beacon_storage_pointer_request()
    |> mock_oz_storage_pointer_request("0x0000000000000000000000000000000000000000000000000000000000000001")
  end

  def get_eip1967_implementation_zero_addresses do
    EthereumJSONRPC.Mox
    |> mock_logic_storage_pointer_request()
    |> mock_beacon_storage_pointer_request()
    |> mock_oz_storage_pointer_request()
    |> mock_eip_1822_storage_pointer_request()
  end

  def get_eip1967_implementation_error_response do
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
      {:error, "error"}
    end)
    |> mock_beacon_storage_pointer_request()
    |> mock_oz_storage_pointer_request()
    |> mock_eip_1822_storage_pointer_request()
  end
end
