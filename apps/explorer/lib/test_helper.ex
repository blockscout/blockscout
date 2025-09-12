defmodule Explorer.TestHelper do
  @moduledoc false

  import Mox

  alias ABI.TypeEncoder
  alias Explorer.Chain.Hash
  alias Explorer.Chain.SmartContract.Proxy.ResolvedDelegateProxy

  @zero_address_hash %Hash{byte_count: 20, bytes: <<0::160>>}
  @random_beacon_address_hash %Hash{byte_count: 20, bytes: <<0x3C7EC3E3B80D78FBDD348D796466AB828B45234F::160>>}
  @random_address_manager_address_hash %Hash{byte_count: 20, bytes: <<0xBFCEF74A0522F50A48C759D05BCE97FAB2CA84C6::160>>}

  @implementation_name_storage_value "0x494d504c454d454e544154494f4e00000000000000000000000000000000001c"
  # cast cd 'getAddress(string)' IMPLEMENTATION
  @address_manager_calldata "0xbf40fac10000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000e494d504c454d454e544154494f4e000000000000000000000000000000000000"

  def mock_erc7760_basic_requests(
        mox,
        error?,
        %Hash{} = address_hash \\ @zero_address_hash
      ) do
    expect(mox, :json_rpc, fn [
                                %{
                                  id: id,
                                  method: "eth_getStorageAt",
                                  params: [
                                    _,
                                    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                    "latest"
                                  ]
                                }
                              ],
                              _options ->
      if error?,
        do: {:error, "error"},
        else:
          {:ok,
           [
             %{id: id, result: address_hash_to_full_hash_string(address_hash)}
           ]}
    end)
  end

  def mock_erc7760_beacon_requests(
        mox,
        error?,
        %Hash{} = address_hash \\ @zero_address_hash
      ) do
    if error? do
      expect(mox, :json_rpc, fn [
                                  %{
                                    id: _,
                                    method: "eth_getStorageAt",
                                    params: [
                                      _,
                                      "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
                                      "latest"
                                    ]
                                  }
                                ],
                                _options ->
        {:error, "error"}
      end)
    else
      beacon_address_hash_string = to_string(@random_beacon_address_hash)

      mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  method: "eth_getStorageAt",
                                  params: [
                                    _,
                                    "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
                                    "latest"
                                  ]
                                }
                              ],
                              _options ->
        {:ok,
         [
           %{id: id, result: address_hash_to_full_hash_string(@random_beacon_address_hash)}
         ]}
      end)
      |> expect(:json_rpc, fn %{
                                id: _,
                                method: "eth_call",
                                params: [
                                  %{
                                    data: "0x5c60da1b",
                                    to: ^beacon_address_hash_string
                                  },
                                  "latest"
                                ]
                              },
                              _options ->
        {:ok, address_hash_to_full_hash_string(address_hash)}
      end)
    end
  end

  def mock_resolved_delegate_proxy_requests(
        mox,
        %Hash{} = proxy_address_hash,
        %Hash{} = implementation_address_hash \\ @zero_address_hash
      ) do
    proxy_address_hash_string = to_string(proxy_address_hash)
    address_manager_address_hash_string = to_string(@random_address_manager_address_hash)

    [
      storage: implementation_name_slot,
      storage: address_manager_slot
    ] = ResolvedDelegateProxy.get_fetch_requirements(proxy_address_hash)

    mox
    |> expect(:json_rpc, fn [
                              %{
                                id: id1,
                                method: "eth_getStorageAt",
                                params: [
                                  ^proxy_address_hash_string,
                                  ^implementation_name_slot,
                                  "latest"
                                ]
                              },
                              %{
                                id: id2,
                                method: "eth_getStorageAt",
                                params: [
                                  ^proxy_address_hash_string,
                                  ^address_manager_slot,
                                  "latest"
                                ]
                              }
                            ],
                            _options ->
      {:ok,
       [
         %{id: id1, result: @implementation_name_storage_value},
         %{id: id2, result: address_hash_to_full_hash_string(@random_address_manager_address_hash)}
       ]}
    end)
    |> expect(
      :json_rpc,
      fn %{
           id: _,
           method: "eth_call",
           params: [
             %{
               data: @address_manager_calldata,
               to: ^address_manager_address_hash_string
             },
             "latest"
           ]
         },
         _options ->
        {:ok, address_hash_to_full_hash_string(implementation_address_hash)}
      end
    )
  end

  def mock_generic_proxy_requests(mox, mocks \\ []) do
    expect(mox, :json_rpc, fn [
                                %{
                                  id: id1,
                                  method: "eth_getStorageAt",
                                  params: [
                                    _,
                                    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                    "latest"
                                  ]
                                },
                                %{
                                  id: id2,
                                  method: "eth_getStorageAt",
                                  params: [
                                    _,
                                    "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7",
                                    "latest"
                                  ]
                                },
                                %{
                                  id: id3,
                                  method: "eth_getStorageAt",
                                  params: [
                                    _,
                                    "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
                                    "latest"
                                  ]
                                },
                                %{
                                  id: id4,
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data: "0x52ef6b2c",
                                      to: _
                                    },
                                    "latest"
                                  ]
                                },
                                %{
                                  id: id5,
                                  method: "eth_getStorageAt",
                                  params: [
                                    _,
                                    "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3",
                                    "latest"
                                  ]
                                }
                                | rest
                              ],
                              _options ->
      {:ok,
       [
         mocks |> Keyword.get(:eip1967, @zero_address_hash) |> encode_in_batch_response(id1),
         mocks |> Keyword.get(:eip1822, @zero_address_hash) |> encode_in_batch_response(id2),
         mocks |> Keyword.get(:eip1967_beacon, @zero_address_hash) |> encode_in_batch_response(id3),
         %{id: id4, error: "error"},
         mocks |> Keyword.get(:eip1967_oz, @zero_address_hash) |> encode_in_batch_response(id5)
       ] ++
         Enum.map(rest, fn
           %{id: id6, method: "eth_call", params: [%{data: "0x5c60da1b", to: _}, "latest"]} ->
             mocks |> Keyword.get(:basic_implementation, @zero_address_hash) |> encode_in_batch_response(id6)
         end)}
    end)

    if Keyword.get(mocks, :eip1967_beacon) && Keyword.get(mocks, :eip1967_beacon_implementation) do
      beacon_address_hash_string = to_string(Keyword.get(mocks, :eip1967_beacon))

      expect(mox, :json_rpc, fn %{
                                  id: 0,
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data: "0x5c60da1b",
                                      to: ^beacon_address_hash_string
                                    },
                                    "latest"
                                  ]
                                },
                                _options ->
        {:ok, address_hash_to_full_hash_string(Keyword.get(mocks, :eip1967_beacon_implementation))}
      end)
    end
  end

  defp encode_in_batch_response(%Hash{byte_count: 20, bytes: _} = address_hash, id),
    do: %{id: id, result: address_hash_to_full_hash_string(address_hash)}

  defp encode_in_batch_response(:error, id),
    do: %{id: id, error: "error"}

  defp address_hash_to_full_hash_string(%Hash{byte_count: 20, bytes: bytes}) do
    to_string(%Hash{byte_count: 32, bytes: <<0::96, bytes::binary>>})
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

  def get_chain_id_mock do
    expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn %{
                                                   id: _id,
                                                   method: "eth_chainId",
                                                   params: []
                                                 },
                                                 _options ->
      {:ok, "0x1"}
    end)
  end

  def topic(topic_hex_string) do
    {:ok, topic} = Explorer.Chain.Hash.Full.cast(topic_hex_string)
    topic
  end
end
