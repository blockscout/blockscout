defmodule Explorer.Token.InstanceMetadataRetrieverTest do
  use EthereumJSONRPC.Case

  alias EthereumJSONRPC.Encoder
  alias Explorer.Token.InstanceMetadataRetriever
  alias Plug.Conn

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  @abi [
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [
        %{"type" => "string", "name" => ""}
      ],
      "name" => "tokenURI",
      "inputs" => [
        %{
          "type" => "uint256",
          "name" => "_tokenId"
        }
      ],
      "constant" => true
    }
  ]

  @abi_uri [
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [
        %{
          "type" => "string",
          "name" => "",
          "internalType" => "string"
        }
      ],
      "name" => "uri",
      "inputs" => [
        %{
          "type" => "uint256",
          "name" => "_id",
          "internalType" => "uint256"
        }
      ],
      "constant" => true
    }
  ]

  describe "fetch_metadata/2" do
    @tag :no_nethermind
    @tag :no_geth
    test "fetches json metadata", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_call",
                                    params: [
                                      %{
                                        data:
                                          "0xc87b56dd000000000000000000000000000000000000000000000000fdd5b9fa9d4bfb20",
                                        to: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"
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
               result:
                 "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003568747470733a2f2f7661756c742e7761727269646572732e636f6d2f31383239303732393934373636373130323439362e6a736f6e0000000000000000000000"
             }
           ]}
        end)
      end

      assert %{
               "c87b56dd" => {:ok, ["https://vault.warriders.com/18290729947667102496.json"]}
             } ==
               InstanceMetadataRetriever.query_contract(
                 "0x5caebd3b32e210e85ce3e9d51638b9c445481567",
                 %{
                   "c87b56dd" => [18_290_729_947_667_102_496]
                 },
                 @abi
               )
    end

    test "fetches json metadata for ERC-1155 token", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_call",
                                    params: [
                                      %{
                                        data:
                                          "0x0e89341c000000000000000000000000000000000000000000000000fdd5b9fa9d4bfb20",
                                        to: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"
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
               result:
                 "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003568747470733a2f2f7661756c742e7761727269646572732e636f6d2f31383239303732393934373636373130323439362e6a736f6e0000000000000000000000"
             }
           ]}
        end)
      end

      assert %{
               "0e89341c" => {:ok, ["https://vault.warriders.com/18290729947667102496.json"]}
             } ==
               InstanceMetadataRetriever.query_contract(
                 "0x5caebd3b32e210e85ce3e9d51638b9c445481567",
                 %{
                   "0e89341c" => [18_290_729_947_667_102_496]
                 },
                 @abi_uri
               )
    end
  end

  describe "fetch_json/1" do
    setup do
      bypass = Bypass.open()

      {:ok, bypass: bypass}
    end

    test "fetches json with latin1 encoding", %{bypass: bypass} do
      json = """
      {
        "name": "Sérgio Mendonça"
      }
      """

      Bypass.expect(bypass, "GET", "/api/card/55265", fn conn ->
        Conn.resp(conn, 200, json)
      end)

      assert {:ok, %{metadata: %{"name" => "Sérgio Mendonça"}}} ==
               InstanceMetadataRetriever.fetch_json(%{
                 "c87b56dd" => {:ok, ["http://localhost:#{bypass.port}/api/card/55265"]}
               })
    end

    test "replace {id} with actual token_id", %{bypass: bypass} do
      json = """
      {
        "name": "Sérgio Mendonça {id}"
      }
      """

      abi =
        [
          %{
            "type" => "function",
            "stateMutability" => "nonpayable",
            "payable" => false,
            "outputs" => [],
            "name" => "tokenURI",
            "inputs" => [
              %{"type" => "string", "name" => "name", "internalType" => "string"}
            ]
          }
        ]
        |> ABI.parse_specification()
        |> Enum.at(0)

      encoded_url =
        abi
        |> Encoder.encode_function_call(["http://localhost:#{bypass.port}/api/card/{id}"])
        |> String.replace("4cf12d26", "")

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: 0,
                                  jsonrpc: "2.0",
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data:
                                        "0xc87b56dd0000000000000000000000000000000000000000000000000000000000000309",
                                      to: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"
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
             error: %{code: -32000, message: "execution reverted"}
           }
         ]}
      end)
      |> expect(:json_rpc, fn [
                                %{
                                  id: 0,
                                  jsonrpc: "2.0",
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data:
                                        "0x0e89341c0000000000000000000000000000000000000000000000000000000000000309",
                                      to: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"
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

      Bypass.expect(
        bypass,
        "GET",
        "/api/card/0000000000000000000000000000000000000000000000000000000000000309",
        fn conn ->
          Conn.resp(conn, 200, json)
        end
      )

      assert {:ok,
              %{
                metadata: %{
                  "name" => "Sérgio Mendonça 0000000000000000000000000000000000000000000000000000000000000309"
                }
              }} ==
               InstanceMetadataRetriever.fetch_metadata("0x5caebd3b32e210e85ce3e9d51638b9c445481567", 777)
    end

    test "decodes json file in tokenURI" do
      data = %{
        "c87b56dd" =>
          {:ok,
           [
             "data:application/json,{\"name\":\"Home%20Address%20-%200x0000000000C1A6066c6c8B9d63e9B6E8865dC117\",\"description\":\"This%20NFT%20can%20be%20redeemed%20on%20HomeWork%20to%20grant%20a%20controller%20the%20exclusive%20right%20to%20deploy%20contracts%20with%20arbitrary%20bytecode%20to%20the%20designated%20home%20address.\",\"image\":\"data:image/svg+xml;charset=utf-8;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNDQgNzIiPjxzdHlsZT48IVtDREFUQVsuQntzdHJva2UtbGluZWpvaW46cm91bmR9LkN7c3Ryb2tlLW1pdGVybGltaXQ6MTB9LkR7c3Ryb2tlLXdpZHRoOjJ9LkV7ZmlsbDojOWI5YjlhfS5Ge3N0cm9rZS1saW5lY2FwOnJvdW5kfV1dPjwvc3R5bGU+PGcgdHJhbnNmb3JtPSJtYXRyaXgoMS4wMiAwIDAgMS4wMiA4LjEgMCkiPjxwYXRoIGZpbGw9IiNmZmYiIGQ9Ik0xOSAzMmgzNHYyNEgxOXoiLz48ZyBzdHJva2U9IiMwMDAiIGNsYXNzPSJCIEMgRCI+PHBhdGggZmlsbD0iI2E1NzkzOSIgZD0iTTI1IDQwaDl2MTZoLTl6Ii8+PHBhdGggZmlsbD0iIzkyZDNmNSIgZD0iTTQwIDQwaDh2N2gtOHoiLz48cGF0aCBmaWxsPSIjZWE1YTQ3IiBkPSJNNTMgMzJIMTl2LTFsMTYtMTYgMTggMTZ6Ii8+PHBhdGggZmlsbD0ibm9uZSIgZD0iTTE5IDMyaDM0djI0SDE5eiIvPjxwYXRoIGZpbGw9IiNlYTVhNDciIGQ9Ik0yOSAyMWwtNSA1di05aDV6Ii8+PC9nPjwvZz48ZyB0cmFuc2Zvcm09Im1hdHJpeCguODQgMCAwIC44NCA2NSA1KSI+PHBhdGggZD0iTTkuNSAyMi45bDQuOCA2LjRhMy4xMiAzLjEyIDAgMCAxLTMgMi4ybC00LjgtNi40Yy4zLTEuNCAxLjYtMi40IDMtMi4yeiIgZmlsbD0iI2QwY2ZjZSIvPjxwYXRoIGZpbGw9IiMwMTAxMDEiIGQ9Ik00MS43IDM4LjVsNS4xLTYuNSIvPjxwYXRoIGQ9Ik00Mi45IDI3LjhMMTguNCA1OC4xIDI0IDYybDIxLjgtMjcuMyAyLjMtMi44eiIgY2xhc3M9IkUiLz48cGF0aCBmaWxsPSIjMDEwMTAxIiBkPSJNNDMuNCAyOS4zbC00LjcgNS44Ii8+PHBhdGggZD0iTTQ2LjggMzJjMy4yIDIuNiA4LjcgMS4yIDEyLjEtMy4yczMuNi05LjkuMy0xMi41bC01LjEgNi41LTIuOC0uMS0uNy0yLjcgNS4xLTYuNWMtMy4yLTIuNi04LjctMS4yLTEyLjEgMy4ycy0zLjYgOS45LS4zIDEyLjUiIGNsYXNzPSJFIi8+PHBhdGggZmlsbD0iI2E1NzkzOSIgZD0iTTI3LjMgMjZsMTEuOCAxNS43IDMuNCAyLjQgOS4xIDE0LjQtMy4yIDIuMy0xIC43LTEwLjItMTMuNi0xLjMtMy45LTExLjgtMTUuN3oiLz48cGF0aCBkPSJNMTIgMTkuOWw1LjkgNy45IDEwLjItNy42LTMuNC00LjVzNi44LTUuMSAxMC43LTQuNWMwIDAtNi42LTMtMTMuMyAxLjFTMTIgMTkuOSAxMiAxOS45eiIgY2xhc3M9IkUiLz48ZyBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAiIGNsYXNzPSJCIEMgRCI+PHBhdGggZD0iTTUyIDU4LjlMNDAuOSA0My4ybC0zLjEtMi4zLTEwLjYtMTQuNy0yLjkgMi4yIDEwLjYgMTQuNyAxLjEgMy42IDExLjUgMTUuNXpNMTIuNSAxOS44bDUuOCA4IDEwLjMtNy40LTMuMy00LjZzNi45LTUgMTAuOC00LjNjMCAwLTYuNi0zLjEtMTMuMy45cy0xMC4zIDcuNC0xMC4zIDcuNHptLTIuNiAyLjlsNC43IDYuNWMtLjUgMS4zLTEuNyAyLjEtMyAyLjJsLTQuNy02LjVjLjMtMS40IDEuNi0yLjQgMy0yLjJ6Ii8+PHBhdGggZD0iTTQxLjMgMzguNWw1LjEtNi41bS0zLjUtMi43bC00LjYgNS44bTguMS0zLjFjMy4yIDIuNiA4LjcgMS4yIDEyLjEtMy4yczMuNi05LjkuMy0xMi41bC01LjEgNi41LTIuOC0uMS0uOC0yLjcgNS4xLTYuNWMtMy4yLTIuNi04LjctMS4yLTEyLjEgMy4yLTMuNCA0LjMtMy42IDkuOS0uMyAxMi41IiBjbGFzcz0iRiIvPjxwYXRoIGQ9Ik0zMC44IDQ0LjRMMTkgNTguOWw0IDMgMTAtMTIuNyIgY2xhc3M9IkYiLz48L2c+PC9nPjwvc3ZnPg==\"}"
           ]}
      }

      assert InstanceMetadataRetriever.fetch_json(data) ==
               {:ok,
                %{
                  metadata: %{
                    "description" =>
                      "This NFT can be redeemed on HomeWork to grant a controller the exclusive right to deploy contracts with arbitrary bytecode to the designated home address.",
                    "image" =>
                      "data:image/svg+xml;charset=utf-8;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNDQgNzIiPjxzdHlsZT48IVtDREFUQVsuQntzdHJva2UtbGluZWpvaW46cm91bmR9LkN7c3Ryb2tlLW1pdGVybGltaXQ6MTB9LkR7c3Ryb2tlLXdpZHRoOjJ9LkV7ZmlsbDojOWI5YjlhfS5Ge3N0cm9rZS1saW5lY2FwOnJvdW5kfV1dPjwvc3R5bGU+PGcgdHJhbnNmb3JtPSJtYXRyaXgoMS4wMiAwIDAgMS4wMiA4LjEgMCkiPjxwYXRoIGZpbGw9IiNmZmYiIGQ9Ik0xOSAzMmgzNHYyNEgxOXoiLz48ZyBzdHJva2U9IiMwMDAiIGNsYXNzPSJCIEMgRCI+PHBhdGggZmlsbD0iI2E1NzkzOSIgZD0iTTI1IDQwaDl2MTZoLTl6Ii8+PHBhdGggZmlsbD0iIzkyZDNmNSIgZD0iTTQwIDQwaDh2N2gtOHoiLz48cGF0aCBmaWxsPSIjZWE1YTQ3IiBkPSJNNTMgMzJIMTl2LTFsMTYtMTYgMTggMTZ6Ii8+PHBhdGggZmlsbD0ibm9uZSIgZD0iTTE5IDMyaDM0djI0SDE5eiIvPjxwYXRoIGZpbGw9IiNlYTVhNDciIGQ9Ik0yOSAyMWwtNSA1di05aDV6Ii8+PC9nPjwvZz48ZyB0cmFuc2Zvcm09Im1hdHJpeCguODQgMCAwIC44NCA2NSA1KSI+PHBhdGggZD0iTTkuNSAyMi45bDQuOCA2LjRhMy4xMiAzLjEyIDAgMCAxLTMgMi4ybC00LjgtNi40Yy4zLTEuNCAxLjYtMi40IDMtMi4yeiIgZmlsbD0iI2QwY2ZjZSIvPjxwYXRoIGZpbGw9IiMwMTAxMDEiIGQ9Ik00MS43IDM4LjVsNS4xLTYuNSIvPjxwYXRoIGQ9Ik00Mi45IDI3LjhMMTguNCA1OC4xIDI0IDYybDIxLjgtMjcuMyAyLjMtMi44eiIgY2xhc3M9IkUiLz48cGF0aCBmaWxsPSIjMDEwMTAxIiBkPSJNNDMuNCAyOS4zbC00LjcgNS44Ii8+PHBhdGggZD0iTTQ2LjggMzJjMy4yIDIuNiA4LjcgMS4yIDEyLjEtMy4yczMuNi05LjkuMy0xMi41bC01LjEgNi41LTIuOC0uMS0uNy0yLjcgNS4xLTYuNWMtMy4yLTIuNi04LjctMS4yLTEyLjEgMy4ycy0zLjYgOS45LS4zIDEyLjUiIGNsYXNzPSJFIi8+PHBhdGggZmlsbD0iI2E1NzkzOSIgZD0iTTI3LjMgMjZsMTEuOCAxNS43IDMuNCAyLjQgOS4xIDE0LjQtMy4yIDIuMy0xIC43LTEwLjItMTMuNi0xLjMtMy45LTExLjgtMTUuN3oiLz48cGF0aCBkPSJNMTIgMTkuOWw1LjkgNy45IDEwLjItNy42LTMuNC00LjVzNi44LTUuMSAxMC43LTQuNWMwIDAtNi42LTMtMTMuMyAxLjFTMTIgMTkuOSAxMiAxOS45eiIgY2xhc3M9IkUiLz48ZyBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAiIGNsYXNzPSJCIEMgRCI+PHBhdGggZD0iTTUyIDU4LjlMNDAuOSA0My4ybC0zLjEtMi4zLTEwLjYtMTQuNy0yLjkgMi4yIDEwLjYgMTQuNyAxLjEgMy42IDExLjUgMTUuNXpNMTIuNSAxOS44bDUuOCA4IDEwLjMtNy40LTMuMy00LjZzNi45LTUgMTAuOC00LjNjMCAwLTYuNi0zLjEtMTMuMy45cy0xMC4zIDcuNC0xMC4zIDcuNHptLTIuNiAyLjlsNC43IDYuNWMtLjUgMS4zLTEuNyAyLjEtMyAyLjJsLTQuNy02LjVjLjMtMS40IDEuNi0yLjQgMy0yLjJ6Ii8+PHBhdGggZD0iTTQxLjMgMzguNWw1LjEtNi41bS0zLjUtMi43bC00LjYgNS44bTguMS0zLjFjMy4yIDIuNiA4LjcgMS4yIDEyLjEtMy4yczMuNi05LjkuMy0xMi41bC01LjEgNi41LTIuOC0uMS0uOC0yLjcgNS4xLTYuNWMtMy4yLTIuNi04LjctMS4yLTEyLjEgMy4yLTMuNCA0LjMtMy42IDkuOS0uMyAxMi41IiBjbGFzcz0iRiIvPjxwYXRoIGQ9Ik0zMC44IDQ0LjRMMTkgNTguOWw0IDMgMTAtMTIuNyIgY2xhc3M9IkYiLz48L2c+PC9nPjwvc3ZnPg==",
                    "name" => "Home Address - 0x0000000000C1A6066c6c8B9d63e9B6E8865dC117"
                  }
                }}
    end

    test "decodes base64 encoded JSON in tokenURI" do
      data = %{
        "c87b56dd" =>
          {:ok,
           [
             "data:application/json;base64,eyJuYW1lIjoiVmFsb3JhIEV4cGxvcmEiLCJpbWFnZSI6ImlwZnM6Ly9RbWVuelZlOUJzQXFzSjlvQ3BpU3JtdVBaY0JhVjJyZFlNb3ljcnR2UWUzZktnIn0="
           ]}
      }

      assert InstanceMetadataRetriever.fetch_json(data) ==
               {:ok,
                %{
                  metadata: %{
                    "name" => "Valora Explora",
                    "image" => "ipfs://QmenzVe9BsAqsJ9oCpiSrmuPZcBaV2rdYMoycrtvQe3fKg"
                  }
                }}
    end
  end
end
