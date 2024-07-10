defmodule Explorer.TestHelper do
  @moduledoc false

  import Mox

  alias ABI.TypeEncoder

  def mock_logic_storage_pointer_request(
        mox,
        error?,
        resp \\ "0x0000000000000000000000000000000000000000000000000000000000000000"
      ) do
    response = if error?, do: {:error, "error"}, else: {:ok, resp}

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
      response
    end)
  end

  def mock_beacon_storage_pointer_request(
        mox,
        error?,
        resp \\ "0x0000000000000000000000000000000000000000000000000000000000000000"
      ) do
    response = if error?, do: {:error, "error"}, else: {:ok, resp}

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
      response
    end)
  end

  def mock_oz_storage_pointer_request(
        mox,
        error?,
        resp \\ "0x0000000000000000000000000000000000000000000000000000000000000000"
      ) do
    response = if error?, do: {:error, "error"}, else: {:ok, resp}

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
      response
    end)
  end

  def mock_eip_1822_storage_pointer_request(
        mox,
        error?,
        resp \\ "0x0000000000000000000000000000000000000000000000000000000000000000"
      ) do
    response = if error?, do: {:error, "error"}, else: {:ok, resp}

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
      response
    end)
  end

  def get_eip1967_implementation_non_zero_address(address_hash_string) do
    EthereumJSONRPC.Mox
    |> mock_logic_storage_pointer_request(false)
    |> mock_beacon_storage_pointer_request(false)
    |> mock_oz_storage_pointer_request(false, "0x000000000000000000000000" <> address_hash_string)
  end

  def get_eip1967_implementation_zero_addresses do
    EthereumJSONRPC.Mox
    |> mock_logic_storage_pointer_request(false)
    |> mock_beacon_storage_pointer_request(false)
    |> mock_oz_storage_pointer_request(false)
    |> mock_eip_1822_storage_pointer_request(false)
  end

  def get_eip1967_implementation_error_response do
    EthereumJSONRPC.Mox
    |> mock_logic_storage_pointer_request(true)
    |> mock_beacon_storage_pointer_request(true)
    |> mock_oz_storage_pointer_request(true)
    |> mock_eip_1822_storage_pointer_request(true)
  end

  def fetch_token_uri_mock(url, token_contract_address_hash_string) do
    encoded_url =
      "0x" <>
        ([url]
         |> TypeEncoder.encode(%ABI.FunctionSelector{
           function: nil,
           types: [
             :string
           ]
         })
         |> Base.encode16(case: :lower))

    EthereumJSONRPC.Mox
    |> expect(:json_rpc, fn [
                              %{
                                id: 0,
                                jsonrpc: "2.0",
                                method: "eth_call",
                                params: [
                                  %{
                                    data: "0xc87b56dd0000000000000000000000000000000000000000000000000000000000000001",
                                    to: ^token_contract_address_hash_string
                                  },
                                  "latest"
                                ]
                              }
                            ],
                            _options ->
      {:ok,
       [
         %{
           id: 0,
           jsonrpc: "2.0",
           result: encoded_url
         }
       ]}
    end)
  end
end
