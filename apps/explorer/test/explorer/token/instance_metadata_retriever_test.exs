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
      path = "/api/card/55265"

      json = """
      {
        "name": "Sérgio Mendonça"
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      assert {:ok, %{metadata: %{"name" => "Sérgio Mendonça"}}} ==
               InstanceMetadataRetriever.fetch_json(%{
                 "c87b56dd" => {:ok, ["http://localhost:#{bypass.port}#{path}"]}
               })
    end

    test "fetches json metadata for kitties" do
      Application.put_env(:explorer, :http_adapter, Explorer.Mox.HTTPoison)

      result =
        "{\"id\":100500,\"name\":\"KittyBlue_2_Lemonade\",\"generation\":20,\"genes\":\"623509754227292470437941473598751240781530569131665917719736997423495595\",\"created_at\":\"2017-12-06T01:56:27.000Z\",\"birthday\":\"2017-12-06T00:00:00.000Z\",\"image_url\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/100500.svg\",\"image_url_cdn\":\"https://img.cn.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/100500.svg\",\"color\":\"strawberry\",\"background_color\":\"#ffe0e5\",\"bio\":\"Shalom! I'm KittyBlue_2_Lemonade. I'm a professional Foreign Film Director and I love cantaloupe. I'm convinced that the world is flat. One day I'll prove it. It's pawesome to meet you!\",\"kitty_type\":null,\"is_fancy\":false,\"is_exclusive\":false,\"is_special_edition\":false,\"fancy_type\":null,\"language\":\"en\",\"is_prestige\":false,\"prestige_type\":null,\"prestige_ranking\":null,\"prestige_time_limit\":null,\"status\":{\"is_ready\":true,\"is_gestating\":false,\"cooldown\":1410310201506,\"dynamic_cooldown\":1475064986478,\"cooldown_index\":10,\"cooldown_end_block\":0,\"pending_tx_type\":null,\"pending_tx_since\":null},\"purrs\":{\"count\":1,\"is_purred\":false},\"watchlist\":{\"count\":0,\"is_watchlisted\":false},\"hatcher\":{\"address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\",\"image\":\"14\",\"nickname\":\"KittyBlu\",\"hasDapper\":false,\"twitter_id\":null,\"twitter_image_url\":null,\"twitter_handle\":null},\"auction\":{},\"offer\":{},\"owner\":{\"address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\",\"hasDapper\":false,\"twitter_id\":null,\"twitter_image_url\":null,\"twitter_handle\":null,\"image\":\"14\",\"nickname\":\"KittyBlu\"},\"matron\":{\"id\":46234,\"name\":\"KittyBlue_1_Limegreen\",\"generation\":10,\"enhanced_cattributes\":[{\"type\":\"body\",\"kittyId\":19631,\"position\":105,\"description\":\"cymric\"},{\"type\":\"coloreyes\",\"kittyId\":40356,\"position\":263,\"description\":\"limegreen\"},{\"type\":\"eyes\",\"kittyId\":3185,\"position\":16,\"description\":\"raisedbrow\"},{\"type\":\"pattern\",\"kittyId\":46234,\"position\":-1,\"description\":\"totesbasic\"},{\"type\":\"mouth\",\"kittyId\":46234,\"position\":-1,\"description\":\"happygokitty\"},{\"type\":\"colorprimary\",\"kittyId\":46234,\"position\":-1,\"description\":\"greymatter\"},{\"type\":\"colorsecondary\",\"kittyId\":46234,\"position\":-1,\"description\":\"lemonade\"},{\"type\":\"colortertiary\",\"kittyId\":46234,\"position\":-1,\"description\":\"granitegrey\"}],\"owner_wallet_address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\",\"owner\":{\"address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\"},\"created_at\":\"2017-12-03T21:29:17.000Z\",\"image_url\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/46234.svg\",\"image_url_cdn\":\"https://img.cn.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/46234.svg\",\"color\":\"limegreen\",\"is_fancy\":false,\"kitty_type\":null,\"is_exclusive\":false,\"is_special_edition\":false,\"fancy_type\":null,\"status\":{\"is_ready\":true,\"is_gestating\":false,\"cooldown\":1486487069384},\"hatched\":true,\"wrapped\":false,\"image_url_png\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/46234.png\"},\"sire\":{\"id\":82090,\"name\":null,\"generation\":19,\"enhanced_cattributes\":[{\"type\":\"body\",\"kittyId\":82090,\"position\":-1,\"description\":\"himalayan\"},{\"type\":\"coloreyes\",\"kittyId\":82090,\"position\":-1,\"description\":\"strawberry\"},{\"type\":\"eyes\",\"kittyId\":82090,\"position\":-1,\"description\":\"thicccbrowz\"},{\"type\":\"pattern\",\"kittyId\":82090,\"position\":-1,\"description\":\"totesbasic\"},{\"type\":\"mouth\",\"kittyId\":82090,\"position\":-1,\"description\":\"pouty\"},{\"type\":\"colorprimary\",\"kittyId\":82090,\"position\":-1,\"description\":\"aquamarine\"},{\"type\":\"colorsecondary\",\"kittyId\":82090,\"position\":-1,\"description\":\"chocolate\"},{\"type\":\"colortertiary\",\"kittyId\":82090,\"position\":-1,\"description\":\"granitegrey\"}],\"owner_wallet_address\":\"0x798fdad0cedc4b298fc7d53a982fa0c5f447eaa5\",\"owner\":{\"address\":\"0x798fdad0cedc4b298fc7d53a982fa0c5f447eaa5\"},\"created_at\":\"2017-12-05T06:30:05.000Z\",\"image_url\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/82090.svg\",\"image_url_cdn\":\"https://img.cn.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/82090.svg\",\"color\":\"strawberry\",\"is_fancy\":false,\"is_exclusive\":false,\"is_special_edition\":false,\"fancy_type\":null,\"status\":{\"is_ready\":true,\"is_gestating\":false,\"cooldown\":1486619010030},\"kitty_type\":null,\"hatched\":true,\"wrapped\":false,\"image_url_png\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/82090.png\"},\"children\":[],\"hatched\":true,\"wrapped\":false,\"enhanced_cattributes\":[{\"type\":\"colorprimary\",\"description\":\"greymatter\",\"position\":null,\"kittyId\":100500},{\"type\":\"coloreyes\",\"description\":\"strawberry\",\"position\":null,\"kittyId\":100500},{\"type\":\"body\",\"description\":\"himalayan\",\"position\":null,\"kittyId\":100500},{\"type\":\"colorsecondary\",\"description\":\"lemonade\",\"position\":null,\"kittyId\":100500},{\"type\":\"mouth\",\"description\":\"pouty\",\"position\":null,\"kittyId\":100500},{\"type\":\"pattern\",\"description\":\"totesbasic\",\"position\":null,\"kittyId\":100500},{\"type\":\"eyes\",\"description\":\"thicccbrowz\",\"position\":null,\"kittyId\":100500},{\"type\":\"colortertiary\",\"description\":\"kittencream\",\"position\":null,\"kittyId\":100500},{\"type\":\"secret\",\"description\":\"se5\",\"position\":-1,\"kittyId\":100500},{\"type\":\"purrstige\",\"description\":\"pu20\",\"position\":-1,\"kittyId\":100500}],\"variation\":null,\"variation_ranking\":null,\"image_url_png\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/100500.png\",\"items\":[]}"

      Explorer.Mox.HTTPoison
      |> expect(:get, fn "https://api.cryptokitties.co/kitties/100500", _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: result}}
      end)

      {:ok, %{metadata: metadata}} =
        InstanceMetadataRetriever.fetch_metadata("0x06012c8cf97bead5deae237070f9587f8e7a266d", 100_500)

      assert Map.get(metadata, "name") == "KittyBlue_2_Lemonade"

      Application.put_env(:explorer, :http_adapter, HTTPoison)
    end

    test "fetches json metadata when HTTP status 301", %{bypass: bypass} do
      path = "/1302"

      attributes = """
      [
        {"trait_type": "Mouth", "value": "Discomfort"},
        {"trait_type": "Background", "value": "Army Green"},
        {"trait_type": "Eyes", "value": "Wide Eyed"},
        {"trait_type": "Fur", "value": "Black"},
        {"trait_type": "Earring", "value": "Silver Hoop"},
        {"trait_type": "Hat", "value": "Sea Captain's Hat"}
      ]
      """

      json = """
      {
        "attributes": #{attributes}
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      {:ok, %{metadata: metadata}} =
        InstanceMetadataRetriever.fetch_metadata_from_uri("http://localhost:#{bypass.port}#{path}")

      assert Map.get(metadata, "attributes") == Jason.decode!(attributes)
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

    test "decodes base64 encoded json file in tokenURI" do
      data = %{
        "c87b56dd" =>
          {:ok,
           [
             "data:application/json;base64,eyJuYW1lIjogIi54ZGFpIiwgImRlc2NyaXB0aW9uIjogIlB1bmsgRG9tYWlucyBkaWdpdGFsIGlkZW50aXR5LiBWaXNpdCBodHRwczovL3B1bmsuZG9tYWlucy8iLCAiaW1hZ2UiOiAiZGF0YTppbWFnZS9zdmcreG1sO2Jhc2U2NCxQSE4yWnlCNGJXeHVjejBpYUhSMGNEb3ZMM2QzZHk1M015NXZjbWN2TWpBd01DOXpkbWNpSUhacFpYZENiM2c5SWpBZ01DQTFNREFnTlRBd0lpQjNhV1IwYUQwaU5UQXdJaUJvWldsbmFIUTlJalV3TUNJK1BHUmxabk0rUEd4cGJtVmhja2R5WVdScFpXNTBJR2xrUFNKbmNtRmtJaUI0TVQwaU1DVWlJSGt4UFNJd0pTSWdlREk5SWpFd01DVWlJSGt5UFNJd0pTSStQSE4wYjNBZ2IyWm1jMlYwUFNJd0pTSWdjM1I1YkdVOUluTjBiM0F0WTI5c2IzSTZjbWRpS0RVNExERTNMREV4TmlrN2MzUnZjQzF2Y0dGamFYUjVPakVpSUM4K1BITjBiM0FnYjJabWMyVjBQU0l4TURBbElpQnpkSGxzWlQwaWMzUnZjQzFqYjJ4dmNqcHlaMklvTVRFMkxESTFMREUzS1R0emRHOXdMVzl3WVdOcGRIazZNU0lnTHo0OEwyeHBibVZoY2tkeVlXUnBaVzUwUGp3dlpHVm1jejQ4Y21WamRDQjRQU0l3SWlCNVBTSXdJaUIzYVdSMGFEMGlOVEF3SWlCb1pXbG5hSFE5SWpVd01DSWdabWxzYkQwaWRYSnNLQ05uY21Ga0tTSXZQangwWlhoMElIZzlJalV3SlNJZ2VUMGlOVEFsSWlCa2IyMXBibUZ1ZEMxaVlYTmxiR2x1WlQwaWJXbGtaR3hsSWlCbWFXeHNQU0ozYUdsMFpTSWdkR1Y0ZEMxaGJtTm9iM0k5SW0xcFpHUnNaU0lnWm05dWRDMXphWHBsUFNKNExXeGhjbWRsSWo0dWVHUmhhVHd2ZEdWNGRENDhkR1Y0ZENCNFBTSTFNQ1VpSUhrOUlqY3dKU0lnWkc5dGFXNWhiblF0WW1GelpXeHBibVU5SW0xcFpHUnNaU0lnWm1sc2JEMGlkMmhwZEdVaUlIUmxlSFF0WVc1amFHOXlQU0p0YVdSa2JHVWlQbkIxYm1zdVpHOXRZV2x1Y3p3dmRHVjRkRDQ4TDNOMlp6ND0ifQ=="
           ]}
      }

      assert InstanceMetadataRetriever.fetch_json(data) ==
               {:ok,
                %{
                  metadata: %{
                    "name" => ".xdai",
                    "description" => "Punk Domains digital identity. Visit https://punk.domains/",
                    "image" =>
                      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA1MDAgNTAwIiB3aWR0aD0iNTAwIiBoZWlnaHQ9IjUwMCI+PGRlZnM+PGxpbmVhckdyYWRpZW50IGlkPSJncmFkIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIwJSI+PHN0b3Agb2Zmc2V0PSIwJSIgc3R5bGU9InN0b3AtY29sb3I6cmdiKDU4LDE3LDExNik7c3RvcC1vcGFjaXR5OjEiIC8+PHN0b3Agb2Zmc2V0PSIxMDAlIiBzdHlsZT0ic3RvcC1jb2xvcjpyZ2IoMTE2LDI1LDE3KTtzdG9wLW9wYWNpdHk6MSIgLz48L2xpbmVhckdyYWRpZW50PjwvZGVmcz48cmVjdCB4PSIwIiB5PSIwIiB3aWR0aD0iNTAwIiBoZWlnaHQ9IjUwMCIgZmlsbD0idXJsKCNncmFkKSIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSJ4LWxhcmdlIj4ueGRhaTwvdGV4dD48dGV4dCB4PSI1MCUiIHk9IjcwJSIgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgZmlsbD0id2hpdGUiIHRleHQtYW5jaG9yPSJtaWRkbGUiPnB1bmsuZG9tYWluczwvdGV4dD48L3N2Zz4="
                  }
                }}
    end

    test "decodes base64 encoded json file (with unicode string) in tokenURI" do
      data = %{
        "c87b56dd" =>
          {:ok,
           [
             "data:application/json;base64,eyJkZXNjcmlwdGlvbiI6ICJQdW5rIERvbWFpbnMgZGlnaXRhbCBpZGVudGl0eSDDry4gVmlzaXQgaHR0cHM6Ly9wdW5rLmRvbWFpbnMvIn0="
           ]}
      }

      assert InstanceMetadataRetriever.fetch_json(data) ==
               {:ok,
                %{
                  metadata: %{
                    "description" => "Punk Domains digital identity ï. Visit https://punk.domains/"
                  }
                }}
    end

    test "fetches image from ipfs link directly", %{bypass: bypass} do
      path = "/ipfs/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"

      json = """
      {
        "image": "https://ipfs.io/ipfs/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      data = %{
        "c87b56dd" =>
          {:ok,
           [
             "http://localhost:#{bypass.port}#{path}"
           ]}
      }

      assert {:ok,
              %{
                metadata: %{
                  "image" => "https://ipfs.io/ipfs/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"
                }
              }} == InstanceMetadataRetriever.fetch_json(data)
    end

    test "Fetches metadata from ipfs", %{bypass: bypass} do
      path = "/ipfs/bafybeid4ed2ua7fwupv4nx2ziczr3edhygl7ws3yx6y2juon7xakgj6cfm/51.json"

      json = """
      {
        "image": "ipfs://bafybeihxuj3gxk7x5p36amzootyukbugmx3pw7dyntsrohg3se64efkuga/51.png"
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      data = %{
        "c87b56dd" =>
          {:ok,
           [
             "http://localhost:#{bypass.port}#{path}"
           ]}
      }

      {:ok,
       %{
         metadata: metadata
       }} = InstanceMetadataRetriever.fetch_json(data)

      assert "ipfs://bafybeihxuj3gxk7x5p36amzootyukbugmx3pw7dyntsrohg3se64efkuga/51.png" == Map.get(metadata, "image")
    end

    test "Fetches metadata from '${url}'", %{bypass: bypass} do
      path = "/data/8/8578.json"

      data = %{
        "c87b56dd" =>
          {:ok,
           [
             "'http://localhost:#{bypass.port}#{path}'"
           ]}
      }

      json = """
      {
        "attributes": [
          {"trait_type": "Character", "value": "Blue Suit Boxing Glove"},
          {"trait_type": "Face", "value": "Wink"},
          {"trait_type": "Hat", "value": "Blue"},
          {"trait_type": "Background", "value": "Red Carpet"}
        ],
        "image": "https://cards.collecttrumpcards.com/cards/0c68b1ab6.jpg",
        "name": "Trump Digital Trading Card #8578",
        "tokeId": 8578
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      assert {:ok,
              %{
                metadata: Jason.decode!(json)
              }} == InstanceMetadataRetriever.fetch_json(data)
    end

    test "Process custom execution reverted" do
      data = %{
        "c87b56dd" =>
          {:error,
           "(3) execution reverted: Nonexistent token (0x08c379a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000114e6f6e6578697374656e7420746f6b656e000000000000000000000000000000)"}
      }

      assert {:ok, %{error: "VM execution error"}} == InstanceMetadataRetriever.fetch_json(data)
    end

    test "Process CIDv0 IPFS links" do
      data = "QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"

      result = %{
        "name" => "asda",
        "description" => "asda",
        "salePrice" => 34,
        "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
        "collectionId" => "1871_1665123820823"
      }

      Application.put_env(:explorer, :http_adapter, Explorer.Mox.HTTPoison)

      Explorer.Mox.HTTPoison
      |> expect(:get, fn "https://ipfs.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP", _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(result)}}
      end)

      assert {:ok,
              %{
                metadata: %{
                  "collectionId" => "1871_1665123820823",
                  "description" => "asda",
                  "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
                  "name" => "asda",
                  "salePrice" => 34
                }
              }} == InstanceMetadataRetriever.fetch_json(data)

      Application.put_env(:explorer, :http_adapter, HTTPoison)
    end

    test "Process URI directly from link", %{bypass: bypass} do
      path = "/api/dejobio/v1/nftproduct/1"

      json = """
      {
          "image": "https:\/\/cdn.discordapp.com\/attachments\/1008567215739650078\/1080111780858187796\/savechives_a_dragon_playing_football_in_a_city_full_of_flowers__0739cc42-aae1-4909-a964-3f9c0ed1a9ed.png",
          "external_url": "https:\/\/dejob.io\/blue-reign-the-dragon-football-champion-of-the-floral-city\/",
          "name": "Blue Reign: The Dragon Football Champion of the Floral City",
          "description": "Test",
          "attributes": [
              {
                  "trait_type": "Product Type",
                  "value": "Book"
              },
              {
                  "display_type": "number",
                  "trait_type": "Total Sold",
                  "value": "0"
              },
              {
                  "display_type": "number",
                  "trait_type": "Success Sold",
                  "value": "0"
              },
              {
                  "max_value": "100",
                  "trait_type": "Success Rate",
                  "value": "0"
              }
          ]
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      assert {:ok,
              %{
                metadata: Jason.decode!(json)
              }} == InstanceMetadataRetriever.fetch_json("http://localhost:#{bypass.port}#{path}")
    end
  end
end
