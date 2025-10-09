defmodule Indexer.Fetcher.TokenInstance.HelperTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Token.Instance
  alias Explorer.Repo
  alias Indexer.Fetcher.TokenInstance.Helper
  alias Plug.Conn

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    bypass = Bypass.open()

    on_exit(fn ->
      Bypass.down(bypass)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)

    {:ok, bypass: bypass}
  end

  describe "fetch instance tests" do
    test "fetches json metadata for kitties" do
      result =
        "{\"id\":100500,\"name\":\"KittyBlue_2_Lemonade\",\"generation\":20,\"genes\":\"623509754227292470437941473598751240781530569131665917719736997423495595\",\"created_at\":\"2017-12-06T01:56:27.000Z\",\"birthday\":\"2017-12-06T00:00:00.000Z\",\"image_url\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/100500.svg\",\"image_url_cdn\":\"https://img.cn.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/100500.svg\",\"color\":\"strawberry\",\"background_color\":\"#ffe0e5\",\"bio\":\"Shalom! I'm KittyBlue_2_Lemonade. I'm a professional Foreign Film Director and I love cantaloupe. I'm convinced that the world is flat. One day I'll prove it. It's pawesome to meet you!\",\"kitty_type\":null,\"is_fancy\":false,\"is_exclusive\":false,\"is_special_edition\":false,\"fancy_type\":null,\"language\":\"en\",\"is_prestige\":false,\"prestige_type\":null,\"prestige_ranking\":null,\"prestige_time_limit\":null,\"status\":{\"is_ready\":true,\"is_gestating\":false,\"cooldown\":1410310201506,\"dynamic_cooldown\":1475064986478,\"cooldown_index\":10,\"cooldown_end_block\":0,\"pending_transaction_type\":null,\"pending_tx_since\":null},\"purrs\":{\"count\":1,\"is_purred\":false},\"watchlist\":{\"count\":0,\"is_watchlisted\":false},\"hatcher\":{\"address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\",\"image\":\"14\",\"nickname\":\"KittyBlu\",\"hasDapper\":false,\"twitter_id\":null,\"twitter_image_url\":null,\"twitter_handle\":null},\"auction\":{},\"offer\":{},\"owner\":{\"address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\",\"hasDapper\":false,\"twitter_id\":null,\"twitter_image_url\":null,\"twitter_handle\":null,\"image\":\"14\",\"nickname\":\"KittyBlu\"},\"matron\":{\"id\":46234,\"name\":\"KittyBlue_1_Limegreen\",\"generation\":10,\"enhanced_cattributes\":[{\"type\":\"body\",\"kittyId\":19631,\"position\":105,\"description\":\"cymric\"},{\"type\":\"coloreyes\",\"kittyId\":40356,\"position\":263,\"description\":\"limegreen\"},{\"type\":\"eyes\",\"kittyId\":3185,\"position\":16,\"description\":\"raisedbrow\"},{\"type\":\"pattern\",\"kittyId\":46234,\"position\":-1,\"description\":\"totesbasic\"},{\"type\":\"mouth\",\"kittyId\":46234,\"position\":-1,\"description\":\"happygokitty\"},{\"type\":\"colorprimary\",\"kittyId\":46234,\"position\":-1,\"description\":\"greymatter\"},{\"type\":\"colorsecondary\",\"kittyId\":46234,\"position\":-1,\"description\":\"lemonade\"},{\"type\":\"colortertiary\",\"kittyId\":46234,\"position\":-1,\"description\":\"granitegrey\"}],\"owner_wallet_address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\",\"owner\":{\"address\":\"0x7b9ea9ac69b8fde875554321472c732eeff06ca0\"},\"created_at\":\"2017-12-03T21:29:17.000Z\",\"image_url\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/46234.svg\",\"image_url_cdn\":\"https://img.cn.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/46234.svg\",\"color\":\"limegreen\",\"is_fancy\":false,\"kitty_type\":null,\"is_exclusive\":false,\"is_special_edition\":false,\"fancy_type\":null,\"status\":{\"is_ready\":true,\"is_gestating\":false,\"cooldown\":1486487069384},\"hatched\":true,\"wrapped\":false,\"image_url_png\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/46234.png\"},\"sire\":{\"id\":82090,\"name\":null,\"generation\":19,\"enhanced_cattributes\":[{\"type\":\"body\",\"kittyId\":82090,\"position\":-1,\"description\":\"himalayan\"},{\"type\":\"coloreyes\",\"kittyId\":82090,\"position\":-1,\"description\":\"strawberry\"},{\"type\":\"eyes\",\"kittyId\":82090,\"position\":-1,\"description\":\"thicccbrowz\"},{\"type\":\"pattern\",\"kittyId\":82090,\"position\":-1,\"description\":\"totesbasic\"},{\"type\":\"mouth\",\"kittyId\":82090,\"position\":-1,\"description\":\"pouty\"},{\"type\":\"colorprimary\",\"kittyId\":82090,\"position\":-1,\"description\":\"aquamarine\"},{\"type\":\"colorsecondary\",\"kittyId\":82090,\"position\":-1,\"description\":\"chocolate\"},{\"type\":\"colortertiary\",\"kittyId\":82090,\"position\":-1,\"description\":\"granitegrey\"}],\"owner_wallet_address\":\"0x798fdad0cedc4b298fc7d53a982fa0c5f447eaa5\",\"owner\":{\"address\":\"0x798fdad0cedc4b298fc7d53a982fa0c5f447eaa5\"},\"created_at\":\"2017-12-05T06:30:05.000Z\",\"image_url\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/82090.svg\",\"image_url_cdn\":\"https://img.cn.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/82090.svg\",\"color\":\"strawberry\",\"is_fancy\":false,\"is_exclusive\":false,\"is_special_edition\":false,\"fancy_type\":null,\"status\":{\"is_ready\":true,\"is_gestating\":false,\"cooldown\":1486619010030},\"kitty_type\":null,\"hatched\":true,\"wrapped\":false,\"image_url_png\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/82090.png\"},\"children\":[],\"hatched\":true,\"wrapped\":false,\"enhanced_cattributes\":[{\"type\":\"colorprimary\",\"description\":\"greymatter\",\"position\":null,\"kittyId\":100500},{\"type\":\"coloreyes\",\"description\":\"strawberry\",\"position\":null,\"kittyId\":100500},{\"type\":\"body\",\"description\":\"himalayan\",\"position\":null,\"kittyId\":100500},{\"type\":\"colorsecondary\",\"description\":\"lemonade\",\"position\":null,\"kittyId\":100500},{\"type\":\"mouth\",\"description\":\"pouty\",\"position\":null,\"kittyId\":100500},{\"type\":\"pattern\",\"description\":\"totesbasic\",\"position\":null,\"kittyId\":100500},{\"type\":\"eyes\",\"description\":\"thicccbrowz\",\"position\":null,\"kittyId\":100500},{\"type\":\"colortertiary\",\"description\":\"kittencream\",\"position\":null,\"kittyId\":100500},{\"type\":\"secret\",\"description\":\"se5\",\"position\":-1,\"kittyId\":100500},{\"type\":\"purrstige\",\"description\":\"pu20\",\"position\":-1,\"kittyId\":100500}],\"variation\":null,\"variation_ranking\":null,\"image_url_png\":\"https://img.cryptokitties.co/0x06012c8cf97bead5deae237070f9587f8e7a266d/100500.png\",\"items\":[]}"

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: "https://api.cryptokitties.co/kitties/100500"}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: result
           }}
        end
      )

      token =
        insert(:token,
          contract_address: build(:address, hash: "0x06012c8cf97bead5deae237070f9587f8e7a266d"),
          type: "ERC-721"
        )

      [%Instance{metadata: metadata}] =
        Helper.batch_fetch_instances([{token.contract_address_hash, 100_500}])

      assert Map.get(metadata, "name") == "KittyBlue_2_Lemonade"
    end

    test "replace {id} with actual token_id", %{bypass: bypass} do
      json = """
      {
        "name": "Sérgio Mendonça {id}"
      }
      """

      encoded_url =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://localhost:#{bypass.port}/api/card/{id}"], %ABI.FunctionSelector{
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

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Bypass.expect(
        bypass,
        "GET",
        "/api/card/0000000000000000000000000000000000000000000000000000000000000309",
        fn conn ->
          Conn.resp(conn, 200, json)
        end
      )

      token =
        insert(:token,
          contract_address: build(:address, hash: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"),
          type: "ERC-1155"
        )

      assert [
               %Instance{
                 metadata: %{
                   "name" => "Sérgio Mendonça 0000000000000000000000000000000000000000000000000000000000000309"
                 }
               }
             ] = Helper.batch_fetch_instances([{token.contract_address_hash, 777}])
    end

    test "fetch ipfs of ipfs/{id} format" do
      address_hash_string = String.downcase("0x7e01CC81fCfdf6a71323900288A69e234C464f63")

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
                                      to: ^address_hash_string
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

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: "https://ipfs.io/ipfs/Qmd9pvThEwgjTBbEkNmmGFbcpJKw17fnRBAT4Td4rcog22"}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: "123",
             headers: [{"Content-Type", "image/jpg"}]
           }}
        end
      )

      token =
        insert(:token,
          contract_address: build(:address, hash: "0x7e01CC81fCfdf6a71323900288A69e234C464f63"),
          type: "ERC-721"
        )

      assert [
               %Instance{
                 metadata: %{
                   "image" => "ipfs://Qmd9pvThEwgjTBbEkNmmGFbcpJKw17fnRBAT4Td4rcog22"
                 }
               }
             ] = Helper.batch_fetch_instances([{token.contract_address_hash, 0}])
    end

    test "re-fetch metadata from baseURI", %{bypass: bypass} do
      json = """
      {
        "name": "123"
      }
      """

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data:
                                        "0xc87b56dd0000000000000000000000000000000000000000000000004f3f5ce294ff3d36",
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
             error: %{code: -32015, data: "Reverted 0x", message: "execution reverted"},
             id: id,
             jsonrpc: "2.0"
           }
         ]}
      end)

      encoded_url =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://localhost:#{bypass.port}/api/card/"], %ABI.FunctionSelector{
             function: nil,
             types: [
               :string
             ]
           })
           |> Base.encode16(case: :lower))

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data: "0x6c0360eb",
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
             id: id,
             jsonrpc: "2.0",
             result: encoded_url
           }
         ]}
      end)

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Bypass.expect(
        bypass,
        "GET",
        "/api/card/5710384980761197878",
        fn conn ->
          Conn.resp(conn, 200, json)
        end
      )

      token =
        insert(:token,
          contract_address: build(:address, hash: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"),
          type: "ERC-721"
        )

      Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Helper, base_uri_retry?: true)

      assert [
               %Instance{
                 metadata: %{
                   "name" => "123"
                 }
               }
             ] =
               Helper.batch_fetch_instances([{token.contract_address_hash, 5_710_384_980_761_197_878}])

      Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Helper, base_uri_retry?: false)
    end

    # https://github.com/blockscout/blockscout/issues/9696
    test "fetch json in utf8 format" do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: 0,
                                  jsonrpc: "2.0",
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data:
                                        "0xc87b56dd000000000000000000000000000000000000000000000000042a0d58bfd13000",
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
               "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000115646174613a6170706c69636174696f6e2f6a736f6e3b757466382c7b226e616d65223a20224f4d4e493430342023333030303637303030303030303030303030222c226465736372697074696f6e223a225468652066726f6e74696572206f66207065726d697373696f6e6c657373206173736574732e222c2265787465726e616c5f75726c223a2268747470733a2f2f747769747465722e636f6d2f6f6d6e69636861696e343034222c22696d616765223a2268747470733a2f2f697066732e696f2f697066732f516d55364447586369535a5854483166554b6b45716a3734503846655850524b7853546a675273564b55516139352f626173652f3330303036373030303030303030303030302e4a5047227d0000000000000000000000"
           }
         ]}
      end)

      token =
        insert(:token,
          contract_address: build(:address, hash: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"),
          type: "ERC-404"
        )

      assert [
               %Instance{
                 metadata: %{
                   "name" => "OMNI404 #300067000000000000",
                   "description" => "The frontier of permissionless assets.",
                   "external_url" => "https://twitter.com/omnichain404",
                   "image" =>
                     "https://ipfs.io/ipfs/QmU6DGXciSZXTH1fUKkEqj74P8FeXPRKxSTjgRsVKUQa95/base/300067000000000000.JPG"
                 }
               }
             ] = Helper.batch_fetch_instances([{token.contract_address_hash, 300_067_000_000_000_000}])
    end

    test "check that decoding error is stored in error, not in metadata", %{bypass: bypass} do
      json = """
      invalid json
      {
        "name": "Sérgio Mendonça {id}"
      }
      """

      encoded_url =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://localhost:#{bypass.port}/api/card/{id}"], %ABI.FunctionSelector{
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

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Bypass.expect(
        bypass,
        "GET",
        "/api/card/0000000000000000000000000000000000000000000000000000000000000309",
        fn conn ->
          Conn.resp(conn, 200, json)
        end
      )

      token =
        insert(:token,
          contract_address: build(:address, hash: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"),
          type: "ERC-1155"
        )

      Helper.batch_fetch_instances([{token.contract_address_hash, 777}])

      %Instance{
        metadata: nil,
        error: "wrong metadata type"
      } = 777 |> Instance.token_instance_query("0x5caebd3b32e210e85ce3e9d51638b9c445481567") |> Repo.one()
    end

    test "check ipfs credentials not exposed to metadata", %{bypass: bypass} do
      old_env = Application.get_env(:indexer, :ipfs)

      public_ipfs_gateway = "https://ipfs.io/ipfs"

      Application.put_env(
        :indexer,
        :ipfs,
        Keyword.merge(old_env,
          gateway_url_param_key: "secret_key",
          gateway_url_param_value: "secret_value",
          gateway_url_param_location: :query,
          gateway_url: "http://localhost:#{bypass.port}",
          public_gateway_url: public_ipfs_gateway
        )
      )

      url = "/ipfs/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"

      encoded_url =
        "0x" <>
          (ABI.TypeEncoder.encode([url], %ABI.FunctionSelector{
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

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Bypass.expect(
        bypass,
        "GET",
        "/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu",
        fn conn ->
          assert conn.params["secret_key"] == "secret_value"

          conn
          |> Conn.put_resp_content_type("image/jpg")
          |> Conn.resp(200, "img")
        end
      )

      token =
        insert(:token,
          contract_address: build(:address, hash: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"),
          type: "ERC-1155"
        )

      assert [
               %Instance{
                 metadata: %{
                   "image" => img_url
                 }
               }
             ] = Helper.batch_fetch_instances([{token.contract_address_hash, 777}])

      refute String.contains?(img_url, "secret_key") || String.contains?(img_url, "secret_value")
      assert img_url == "ipfs://" <> "bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"
      Application.put_env(:indexer, :ipfs, old_env)
    end
  end

  describe "check retries count and refetch after" do
    test "retries count 0 for new instance" do
      config = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Retry)

      coef = config[:exp_timeout_coeff]
      base = config[:exp_timeout_base]
      max_refetch_interval = config[:max_refetch_interval]

      erc_721_token = insert(:token, type: "ERC-721")

      token_instance = build(:token_instance, token_contract_address_hash: erc_721_token.contract_address_hash)

      stub(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok, %{}}
      end)

      Helper.batch_fetch_instances([
        %{contract_address_hash: token_instance.token_contract_address_hash, token_id: token_instance.token_id}
      ])

      now = DateTime.utc_now()
      timeout = min(coef * base ** 0 * 1000, max_refetch_interval)
      refetch_after = DateTime.add(now, timeout, :millisecond)

      [instance] = Repo.all(Instance)

      assert instance.retries_count == 0
      assert DateTime.diff(refetch_after, instance.refetch_after) < 1
      assert !is_nil(instance.error)
      assert not instance.is_banned
    end

    test "proper updates retries count and refetch after on retry" do
      config = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Retry)

      coef = config[:exp_timeout_coeff]
      base = config[:exp_timeout_base]
      max_refetch_interval = config[:max_refetch_interval]

      erc_721_token = insert(:token, type: "ERC-721")

      token_instance =
        insert(:token_instance,
          token_contract_address_hash: erc_721_token.contract_address_hash,
          error: "error",
          metadata: nil
        )

      stub(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok, %{}}
      end)

      Helper.batch_fetch_instances([
        %{contract_address_hash: token_instance.token_contract_address_hash, token_id: token_instance.token_id}
      ])

      now = DateTime.utc_now()
      timeout = min(coef * base ** 1 * 1000, max_refetch_interval)
      refetch_after = DateTime.add(now, timeout, :millisecond)

      [instance] = Repo.all(Instance)

      assert instance.retries_count == 1
      assert DateTime.diff(refetch_after, instance.refetch_after) < 1
      assert !is_nil(instance.error)
      assert not instance.is_banned
    end

    test "success insert after retry" do
      config = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Retry)

      coef = config[:exp_timeout_coeff]
      base = config[:exp_timeout_base]
      max_refetch_interval = config[:max_refetch_interval]

      erc_721_token = insert(:token, type: "ERC-721")

      token_instance = build(:token_instance, token_contract_address_hash: erc_721_token.contract_address_hash)

      Helper.batch_fetch_instances([
        %{contract_address_hash: token_instance.token_contract_address_hash, token_id: token_instance.token_id}
      ])

      Helper.batch_fetch_instances([
        %{contract_address_hash: token_instance.token_contract_address_hash, token_id: token_instance.token_id}
      ])

      now = DateTime.utc_now()
      timeout = min(coef * base ** 1 * 1000, max_refetch_interval)
      refetch_after = DateTime.add(now, timeout, :millisecond)

      [instance] = Repo.all(Instance)

      assert instance.retries_count == 1
      assert DateTime.diff(refetch_after, instance.refetch_after) < 1
      assert !is_nil(instance.error)
      assert not instance.is_banned

      token_address = to_string(erc_721_token.contract_address_hash)

      data =
        "0xc87b56dd" <>
          (ABI.TypeEncoder.encode([token_instance.token_id], [{:uint, 256}]) |> Base.encode16(case: :lower))

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: 0,
                                  jsonrpc: "2.0",
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data: ^data,
                                      to: ^token_address
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
               "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000115646174613a6170706c69636174696f6e2f6a736f6e3b757466382c7b226e616d65223a20224f4d4e493430342023333030303637303030303030303030303030222c226465736372697074696f6e223a225468652066726f6e74696572206f66207065726d697373696f6e6c657373206173736574732e222c2265787465726e616c5f75726c223a2268747470733a2f2f747769747465722e636f6d2f6f6d6e69636861696e343034222c22696d616765223a2268747470733a2f2f697066732e696f2f697066732f516d55364447586369535a5854483166554b6b45716a3734503846655850524b7853546a675273564b55516139352f626173652f3330303036373030303030303030303030302e4a5047227d0000000000000000000000"
           }
         ]}
      end)

      Helper.batch_fetch_instances([
        %{contract_address_hash: token_instance.token_contract_address_hash, token_id: token_instance.token_id}
      ])

      [instance] = Repo.all(Instance)

      assert instance.retries_count == 2
      assert is_nil(instance.refetch_after)
      assert is_nil(instance.error)
      assert not instance.is_banned

      assert instance.metadata == %{
               "name" => "OMNI404 #300067000000000000",
               "description" => "The frontier of permissionless assets.",
               "external_url" => "https://twitter.com/omnichain404",
               "image" =>
                 "https://ipfs.io/ipfs/QmU6DGXciSZXTH1fUKkEqj74P8FeXPRKxSTjgRsVKUQa95/base/300067000000000000.JPG"
             }
    end

    test "Don't fail on high retries count" do
      erc_721_token = insert(:token, type: "ERC-721")

      token_instance =
        insert(:token_instance,
          token_contract_address_hash: erc_721_token.contract_address_hash,
          error: "error",
          metadata: nil,
          retries_count: 50
        )

      stub(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok, %{}}
      end)

      Helper.batch_fetch_instances([
        %{contract_address_hash: token_instance.token_contract_address_hash, token_id: token_instance.token_id}
      ])

      [instance] = Repo.all(Instance)

      assert instance.retries_count == 51
      assert is_nil(instance.refetch_after)
      assert !is_nil(instance.error)
      assert instance.is_banned
    end

    test "set is_banned (VM execution error) if retries_count > 9" do
      erc_721_token = insert(:token, type: "ERC-721")

      token_instance =
        insert(:token_instance,
          token_contract_address_hash: erc_721_token.contract_address_hash,
          error: "error",
          metadata: nil,
          retries_count: 9
        )

      token_address = to_string(erc_721_token.contract_address_hash)

      data =
        "0xc87b56dd" <>
          (ABI.TypeEncoder.encode([Decimal.to_integer(token_instance.token_id)], [{:uint, 256}])
           |> Base.encode16(case: :lower))

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data: ^data,
                                      to: ^token_address
                                    },
                                    "latest"
                                  ]
                                }
                              ],
                              _options ->
        {:ok,
         [
           %{
             error: %{code: -32015, data: "Reverted 0x", message: "execution reverted"},
             id: id,
             jsonrpc: "2.0"
           }
         ]}
      end)

      Helper.batch_fetch_instances([
        %{contract_address_hash: token_instance.token_contract_address_hash, token_id: token_instance.token_id}
      ])

      [instance] = Repo.all(Instance)
      assert instance.error == "VM execution error"
      assert instance.is_banned
    end

    test "don't set is_banned (VM execution error) if retries_count < 9" do
      erc_721_token = insert(:token, type: "ERC-721")

      token_instance =
        insert(:token_instance,
          token_contract_address_hash: erc_721_token.contract_address_hash,
          error: "error",
          metadata: nil,
          retries_count: 8
        )

      token_address = to_string(erc_721_token.contract_address_hash)

      data =
        "0xc87b56dd" <>
          (ABI.TypeEncoder.encode([Decimal.to_integer(token_instance.token_id)], [{:uint, 256}])
           |> Base.encode16(case: :lower))

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data: ^data,
                                      to: ^token_address
                                    },
                                    "latest"
                                  ]
                                }
                              ],
                              _options ->
        {:ok,
         [
           %{
             error: %{code: -32015, data: "Reverted 0x", message: "execution reverted"},
             id: id,
             jsonrpc: "2.0"
           }
         ]}
      end)

      Helper.batch_fetch_instances([
        %{contract_address_hash: token_instance.token_contract_address_hash, token_id: token_instance.token_id}
      ])

      [instance] = Repo.all(Instance)
      assert instance.error =~ "VM execution error"
      assert not instance.is_banned
    end

    test "don't set is_banned (429 error)", %{bypass: bypass} do
      erc_721_token = insert(:token, type: "ERC-721")

      token_instance =
        insert(:token_instance,
          token_contract_address_hash: erc_721_token.contract_address_hash,
          error: "error",
          metadata: nil,
          retries_count: 1000
        )

      token_address = to_string(erc_721_token.contract_address_hash)

      data =
        "0xc87b56dd" <>
          (ABI.TypeEncoder.encode([Decimal.to_integer(token_instance.token_id)], [{:uint, 256}])
           |> Base.encode16(case: :lower))

      encoded_url =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://localhost:#{bypass.port}/api/card"], %ABI.FunctionSelector{
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
                                      data: ^data,
                                      to: ^token_address
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

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Bypass.expect(
        bypass,
        "GET",
        "/api/card",
        fn conn ->
          Conn.resp(conn, 429, "429 Too many requests")
        end
      )

      Helper.batch_fetch_instances([
        %{contract_address_hash: token_instance.token_contract_address_hash, token_id: token_instance.token_id}
      ])

      now = DateTime.utc_now()

      refetch_after =
        DateTime.add(
          now,
          Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Retry)[:max_refetch_interval],
          :millisecond
        )

      [instance] = Repo.all(Instance)
      assert DateTime.diff(refetch_after, instance.refetch_after) < 1
      assert instance.error =~ "request error: 429"
      assert instance.retries_count == 1001
      assert not instance.is_banned
    end
  end
end
