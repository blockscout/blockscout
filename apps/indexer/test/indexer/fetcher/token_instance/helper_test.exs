defmodule Indexer.Fetcher.TokenInstance.HelperTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  alias Explorer.Chain.Token.Instance
  alias EthereumJSONRPC.Encoder
  alias Indexer.Fetcher.TokenInstance.Helper
  alias Plug.Conn

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    bypass = Bypass.open()

    {:ok, bypass: bypass}
  end

  describe "fetch instance tests" do
    test "fetches json metadata for kitties" do
      Application.put_env(:explorer, :http_adapter, Explorer.Mox.HTTPoison)

      result =
        "{\"id\":100500,\"name\":\"KittyBlue_2_Lemonade\",\"generation\":20,\"genes\":\"623509754227292470437941473598751240781530569131665917719736997423495595\",\"created_at\":\"2017-12-06T01:56:27.000Z\",\"birthday\":\"2017-12-06T00:00:00.000Z\",\"image_url\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/100500.svg\",\"image_url_cdn\":\"https://img.cn.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/100500.svg\",\"color\":\"strawberry\",\"background_color\":\"#ffe0e5\",\"bio\":\"Shalom! I'm KittyBlue_2_Lemonade. I'm a professional Foreign Film Director and I love cantaloupe. I'm convinced that the world is flat. One day I'll prove it. It's pawesome to meet you!\",\"kitty_type\":null,\"is_fancy\":false,\"is_exclusive\":false,\"is_special_edition\":false,\"fancy_type\":null,\"language\":\"en\",\"is_prestige\":false,\"prestige_type\":null,\"prestige_ranking\":null,\"prestige_time_limit\":null,\"status\":{\"is_ready\":true,\"is_gestating\":false,\"cooldown\":1410310201506,\"dynamic_cooldown\":1475064986478,\"cooldown_index\":10,\"cooldown_end_block\":0,\"pending_tx_type\":null,\"pending_tx_since\":null},\"purrs\":{\"count\":1,\"is_purred\":false},\"watchlist\":{\"count\":0,\"is_watchlisted\":false},\"hatcher\":{\"address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\",\"image\":\"14\",\"nickname\":\"KittyBlu\",\"hasDapper\":false,\"twitter_id\":null,\"twitter_image_url\":null,\"twitter_handle\":null},\"auction\":{},\"offer\":{},\"owner\":{\"address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\",\"hasDapper\":false,\"twitter_id\":null,\"twitter_image_url\":null,\"twitter_handle\":null,\"image\":\"14\",\"nickname\":\"KittyBlu\"},\"matron\":{\"id\":46234,\"name\":\"KittyBlue_1_Limegreen\",\"generation\":10,\"enhanced_cattributes\":[{\"type\":\"body\",\"kittyId\":19631,\"position\":105,\"description\":\"cymric\"},{\"type\":\"coloreyes\",\"kittyId\":40356,\"position\":263,\"description\":\"limegreen\"},{\"type\":\"eyes\",\"kittyId\":3185,\"position\":16,\"description\":\"raisedbrow\"},{\"type\":\"pattern\",\"kittyId\":46234,\"position\":-1,\"description\":\"totesbasic\"},{\"type\":\"mouth\",\"kittyId\":46234,\"position\":-1,\"description\":\"happygokitty\"},{\"type\":\"colorprimary\",\"kittyId\":46234,\"position\":-1,\"description\":\"greymatter\"},{\"type\":\"colorsecondary\",\"kittyId\":46234,\"position\":-1,\"description\":\"lemonade\"},{\"type\":\"colortertiary\",\"kittyId\":46234,\"position\":-1,\"description\":\"granitegrey\"}],\"owner_wallet_address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\",\"owner\":{\"address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\"},\"created_at\":\"2017-12-03T21:29:17.000Z\",\"image_url\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/46234.svg\",\"image_url_cdn\":\"https://img.cn.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/46234.svg\",\"color\":\"limegreen\",\"is_fancy\":false,\"kitty_type\":null,\"is_exclusive\":false,\"is_special_edition\":false,\"fancy_type\":null,\"status\":{\"is_ready\":true,\"is_gestating\":false,\"cooldown\":1486487069384},\"hatched\":true,\"wrapped\":false,\"image_url_png\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/46234.png\"},\"sire\":{\"id\":82090,\"name\":null,\"generation\":19,\"enhanced_cattributes\":[{\"type\":\"body\",\"kittyId\":82090,\"position\":-1,\"description\":\"himalayan\"},{\"type\":\"coloreyes\",\"kittyId\":82090,\"position\":-1,\"description\":\"strawberry\"},{\"type\":\"eyes\",\"kittyId\":82090,\"position\":-1,\"description\":\"thicccbrowz\"},{\"type\":\"pattern\",\"kittyId\":82090,\"position\":-1,\"description\":\"totesbasic\"},{\"type\":\"mouth\",\"kittyId\":82090,\"position\":-1,\"description\":\"pouty\"},{\"type\":\"colorprimary\",\"kittyId\":82090,\"position\":-1,\"description\":\"aquamarine\"},{\"type\":\"colorsecondary\",\"kittyId\":82090,\"position\":-1,\"description\":\"chocolate\"},{\"type\":\"colortertiary\",\"kittyId\":82090,\"position\":-1,\"description\":\"granitegrey\"}],\"owner_wallet_address\":\"0x798fdad0cedc4b298fc7d53a982fa0c5f447eaa5\",\"owner\":{\"address\":\"0x798fdad0cedc4b298fc7d53a982fa0c5f447eaa5\"},\"created_at\":\"2017-12-05T06:30:05.000Z\",\"image_url\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/82090.svg\",\"image_url_cdn\":\"https://img.cn.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/82090.svg\",\"color\":\"strawberry\",\"is_fancy\":false,\"is_exclusive\":false,\"is_special_edition\":false,\"fancy_type\":null,\"status\":{\"is_ready\":true,\"is_gestating\":false,\"cooldown\":1486619010030},\"kitty_type\":null,\"hatched\":true,\"wrapped\":false,\"image_url_png\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/82090.png\"},\"children\":[],\"hatched\":true,\"wrapped\":false,\"enhanced_cattributes\":[{\"type\":\"colorprimary\",\"description\":\"greymatter\",\"position\":null,\"kittyId\":100500},{\"type\":\"coloreyes\",\"description\":\"strawberry\",\"position\":null,\"kittyId\":100500},{\"type\":\"body\",\"description\":\"himalayan\",\"position\":null,\"kittyId\":100500},{\"type\":\"colorsecondary\",\"description\":\"lemonade\",\"position\":null,\"kittyId\":100500},{\"type\":\"mouth\",\"description\":\"pouty\",\"position\":null,\"kittyId\":100500},{\"type\":\"pattern\",\"description\":\"totesbasic\",\"position\":null,\"kittyId\":100500},{\"type\":\"eyes\",\"description\":\"thicccbrowz\",\"position\":null,\"kittyId\":100500},{\"type\":\"colortertiary\",\"description\":\"kittencream\",\"position\":null,\"kittyId\":100500},{\"type\":\"secret\",\"description\":\"se5\",\"position\":-1,\"kittyId\":100500},{\"type\":\"purrstige\",\"description\":\"pu20\",\"position\":-1,\"kittyId\":100500}],\"variation\":null,\"variation_ranking\":null,\"image_url_png\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/100500.png\",\"items\":[]}"

      Explorer.Mox.HTTPoison
      |> expect(:get, fn "https://api.cryptokitties.co/kitties/100500", _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: result}}
      end)

      insert(:token,
        contract_address: build(:address, hash: "0x06012c8cf97bead5deae237070f9587f8e7a266d"),
        type: "ERC-721"
      )

      [{:ok, %Instance{metadata: metadata}}] =
        Helper.batch_fetch_instances([{"0x06012c8cf97bead5deae237070f9587f8e7a266d", 100_500}])

      assert Map.get(metadata, "name") == "KittyBlue_2_Lemonade"

      Application.put_env(:explorer, :http_adapter, HTTPoison)
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

      insert(:token,
        contract_address: build(:address, hash: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"),
        type: "ERC-1155"
      )

      assert [
               {:ok,
                %Instance{
                  metadata: %{
                    "name" => "Sérgio Mendonça 0000000000000000000000000000000000000000000000000000000000000309"
                  }
                }}
             ] = Helper.batch_fetch_instances([{"0x5caebd3b32e210e85ce3e9d51638b9c445481567", 777}])
    end

    test "fetch ipfs of ipfs/{id} format" do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: 0,
                                  jsonrpc: "2.0",
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data:
                                        "0xc87b56dd0000000000000000000000000000000000000000000000000000000000000000",
                                      to: "0x7e01CC81fCfdf6a71323900288A69e234C464f63"
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
               "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000033697066732f516d6439707654684577676a544262456b4e6d6d47466263704a4b773137666e524241543454643472636f67323200000000000000000000000000"
           }
         ]}
      end)

      Application.put_env(:explorer, :http_adapter, Explorer.Mox.HTTPoison)

      Explorer.Mox.HTTPoison
      |> expect(:get, fn "https://ipfs.io/ipfs/Qmd9pvThEwgjTBbEkNmmGFbcpJKw17fnRBAT4Td4rcog22", _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "123", headers: [{"Content-Type", "image/jpg"}]}}
      end)

      insert(:token,
        contract_address: build(:address, hash: "0x7e01CC81fCfdf6a71323900288A69e234C464f63"),
        type: "ERC-721"
      )

      assert [
               {:ok,
                %Instance{
                  metadata: %{
                    "image" => "https://ipfs.io/ipfs/Qmd9pvThEwgjTBbEkNmmGFbcpJKw17fnRBAT4Td4rcog22"
                  }
                }}
             ] = Helper.batch_fetch_instances([{"0x7e01CC81fCfdf6a71323900288A69e234C464f63", 0}])

      Application.put_env(:explorer, :http_adapter, HTTPoison)
    end
  end
end
