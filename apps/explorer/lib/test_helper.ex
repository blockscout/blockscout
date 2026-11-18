# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.TestHelper do
  @moduledoc false

  import Mox
  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias ABI.TypeEncoder
  alias Explorer.Chain.Hash
  alias Explorer.Chain.SmartContract.Proxy.ResolvedDelegateProxy

  @zero_address_hash %Hash{byte_count: 20, bytes: <<0::160>>}
  @random_beacon_address_hash %Hash{byte_count: 20, bytes: <<0x3C7EC3E3B80D78FBDD348D796466AB828B45234F::160>>}
  @random_address_manager_address_hash %Hash{byte_count: 20, bytes: <<0xBFCEF74A0522F50A48C759D05BCE97FAB2CA84C6::160>>}

  @implementation_name_storage_value "0x494d504c454d454e544154494f4e00000000000000000000000000000000001c"
  # cast cd 'getAddress(string)' IMPLEMENTATION
  @address_manager_calldata "0xbf40fac10000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000e494d504c454d454e544154494f4e000000000000000000000000000000000000"

  # Two different, valid runtime bytecodes with the same MD5 (identical-prefix collision):
  # the first one returns 1 on any call, the second one returns 0x666.
  @md5_colliding_bytecode_1 "0x60016053601f39600051608016601a57600160005260206000f35b61066660005260206000f300000000000000000000000000000000000000000000000000004199fe8e88a3d17d8a5d351c510b2f2434e1736f644c0f362d7e3c2951a4c3f358dde8e05ce9f54667c25611de1759b8427ba3ddf04d9da26026ffbc6373a5d0a441bcc10bb5e681b30f4fbfa305ad4fb711dcaa645c72d7abb5f036066068b7d7333218a748b0f57743945bd363ff63343d1c2b4ffe83044146b728097dc00b"
  @md5_colliding_bytecode_2 "0x60016053601f39600051608016601a57600160005260206000f35b61066660005260206000f300000000000000000000000000000000000000000000000000004199fe8e88a3d17d8a5d351c510b2f2434e173ef644c0f362d7e3c2951a4c3f358dde8e05ce9f54667c25611de9758b8427ba3ddf04d9da26026ff3c6373a5d0a441bcc10bb5e681b30f4fbfa305ad4fb711dc2a645c72d7abb5f036066068b7d7333218a748b0f57743945bd3e3ff63343d1c2b4ffe83044146b7a8097dc00b"

  @doc """
  Returns a pair of different contract bytecodes (hex strings) sharing the same MD5 hash.
  """
  @spec md5_colliding_bytecodes() :: {String.t(), String.t()}
  def md5_colliding_bytecodes, do: {@md5_colliding_bytecode_1, @md5_colliding_bytecode_2}

  # TODO: Execute this for all background migrations
  def run_necessary_background_migrations do
    for background_migration <- [
          Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsBlockNumberTransactionIndexIndexUniqueIndex,
          Explorer.Migrator.HeavyDbIndexOperation.UpdateInternalTransactionsPrimaryKey,
          Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockNumberTransactionIndexIndexUniqueIndex,
          Explorer.Migrator.HeavyDbIndexOperation.UpdateLogsPrimaryKey
        ] do
      case background_migration.db_index_operation_status() do
        :completed ->
          :ok

        _ ->
          execute_background_migration(background_migration)
      end
    end
  end

  defp execute_background_migration(background_migration) do
    case background_migration.db_index_operation() do
      :ok ->
        background_migration.update_cache()
        :ok

      :error ->
        raise "Background migrations failed"
    end
  end

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
         %{id: id4, error: %{code: 3, message: "execution reverted"}},
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

  defp eth_block_number_fake_response(block_quantity, miner \\ "0x0000000000000000000000000000000000000000", id \\ 0) do
    %{
      id: id,
      jsonrpc: "2.0",
      result: %{
        "author" => miner,
        "difficulty" => "0x20000",
        "extraData" => "0x",
        "gasLimit" => "0x663be0",
        "gasUsed" => "0x0",
        "hash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
        "logsBloom" =>
          "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "miner" => miner,
        "number" => block_quantity,
        "parentHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
        "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        "sealFields" => [
          "0x80",
          "0xb8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        ],
        "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
        "signature" =>
          "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "size" => "0x215",
        "stateRoot" => "0xfad4af258fd11939fae0c6c6eec9d340b1caac0b0196fd9a1bc3f489c5bf00b3",
        "step" => "0",
        "timestamp" => "0x0",
        "totalDifficulty" => "0x20000",
        "transactions" => [],
        "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        "uncles" => []
      }
    }
  end

  def eth_get_block_by_number_expectation(block_number) do
    block_quantity = integer_to_quantity(block_number)
    res = eth_block_number_fake_response(block_quantity)

    EthereumJSONRPC.Mox
    |> expect(:json_rpc, fn [
                              %{id: 0, jsonrpc: "2.0", method: "eth_getBlockByNumber", params: [^block_quantity, true]}
                            ],
                            _opts ->
      {:ok, [res]}
    end)
  end

  def eth_get_balance_expectation(address_hash, latest_block_number_hex, balance) do
    expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn [
                                                   %{
                                                     id: id,
                                                     method: "eth_getBalance",
                                                     params: [^address_hash, ^latest_block_number_hex]
                                                   }
                                                 ],
                                                 _options ->
      {:ok, [%{id: id, jsonrpc: "2.0", result: balance}]}
    end)
  end
end
