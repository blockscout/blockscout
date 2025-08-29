defmodule Explorer.Token.MetadataRetrieverTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  alias Explorer.Token.MetadataRetriever
  alias Plug.Conn

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  describe "get_functions_of/1" do
    test "returns all functions read in the smart contract" do
      token = insert(:token, contract_address: build(:contract_address))

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
           end)}
        end
      )

      expected = %{
        name: "Bancor",
        symbol: "BNT",
        total_supply: 1_000_000_000_000_000_000,
        decimals: 18
      }

      assert MetadataRetriever.get_functions_of(token) == expected
    end

    test "returns results for multiple coins" do
      token = insert(:token, contract_address: build(:contract_address))

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
           end)}
        end
      )

      assert {:ok,
              [
                %{
                  name: "Bancor",
                  symbol: "BNT",
                  total_supply: 1_000_000_000_000_000_000,
                  decimals: 18
                },
                %{
                  name: "Bancor",
                  symbol: "BNT",
                  total_supply: 1_000_000_000_000_000_000,
                  decimals: 18
                }
              ]} = MetadataRetriever.get_functions_of([token, token])
    end

    test "returns only the functions that were read without error" do
      token = insert(:token, contract_address: build(:contract_address))

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 id: id,
                 error: %{code: -32015, data: "something", message: "some error"},
                 jsonrpc: "2.0"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 id: id,
                 error: %{code: -32015, data: "something", message: "some error"},
                 jsonrpc: "2.0"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
           end)}
        end
      )

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        2,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 id: id,
                 error: %{code: -32015, data: "something", message: "some error"},
                 jsonrpc: "2.0"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 id: id,
                 error: %{code: -32015, data: "something", message: "some error"},
                 jsonrpc: "2.0"
               }
           end)}
        end
      )

      expected = %{
        name: "Bancor",
        total_supply: 1_000_000_000_000_000_000
      }

      assert MetadataRetriever.get_functions_of(token) == expected
    end

    test "considers the contract address formatted hash when it is an invalid string" do
      contract_address = build(:contract_address, hash: "0x43689531907482bee7e650d18411e284a7337a66")
      token = insert(:token, contract_address: contract_address)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001aa796568616e7a652067676761202075797575206e6e6e6e6e200000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
           end)}
        end
      )

      expected = %{
        name: "0x4368",
        decimals: 18,
        total_supply: 1_000_000_000_000_000_000,
        symbol: "BNT"
      }

      assert MetadataRetriever.get_functions_of(token) == expected
    end

    test "considers the symbol nil when it is an invalid string" do
      original = Application.get_env(:explorer, :token_functions_reader_max_retries)

      Application.put_env(:explorer, :token_functions_reader_max_retries, 1)

      token = insert(:token, contract_address: build(:contract_address))

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               }

             %{id: _id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
               nil

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001aa796568616e7a652067676761202075797575206e6e6e6e6e200000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
           end)
           |> Enum.reject(&is_nil/1)}
        end
      )

      expected = %{
        decimals: 18,
        total_supply: 1_000_000_000_000_000_000,
        symbol: nil
      }

      assert MetadataRetriever.get_functions_of(token) == expected

      Application.put_env(:explorer, :token_functions_reader_max_retries, original)
    end

    test "shortens strings larger than 255 characters" do
      long_token_name_shortened =
        "<button class=\"navbar-toggler\" type=\"button\" data-toggle=\"collapse\" data-target=\"#navbarSupportedContent\" aria-controls=\"navbarSupportedContent\" aria-expanded=\"false\" aria-label=\"<%= gettext(\"Toggle navigation\") %>\"> <span class=\"navbar-toggler-icon\"></sp"

      token = insert(:token, contract_address: build(:contract_address))

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000010c3c627574746f6e20636c6173733d226e61766261722d746f67676c65722220747970653d22627574746f6e2220646174612d746f67676c653d22636f6c6c617073652220646174612d7461726765743d22236e6176626172537570706f72746564436f6e74656e742220617269612d636f6e74726f6c733d226e6176626172537570706f72746564436f6e74656e742220617269612d657870616e6465643d2266616c73652220617269612d6c6162656c3d223c253d20676574746578742822546f67676c65206e617669676174696f6e222920253e223e203c7370616e20636c6173733d226e61766261722d746f67676c65722d69636f6e223e3c2f7370616e3e203c2f627574746f6e3e0000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
           end)}
        end
      )

      expected = %{
        name: long_token_name_shortened,
        decimals: 18,
        total_supply: 1_000_000_000_000_000_000,
        symbol: "BNT"
      }

      assert MetadataRetriever.get_functions_of(token) == expected
    end

    test "shortens strings larger than 255 characters with unicode graphemes" do
      long_token_name_shortened =
        "文章の論旨や要点を短くまとめて表現する要約文。学生の頃、レポート作成などで書いた経験があるものの、それ以降はまったく書いていないという人は多いことでしょう。  しかし、文章"

      token = insert(:token, contract_address: build(:contract_address))

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000128e69687e7aba0e381aee8ab96e697a8e38284e8a681e782b9e38292e79fade3818fe381bee381a8e38281e381a6e8a1a8e78fbee38199e3828be8a681e7b484e69687e38082e5ada6e7949fe381aee9a083e38081e383ace3839de383bce38388e4bd9ce68890e381aae381a9e381a7e69bb8e38184e3819fe7b58ce9a893e3818ce38182e3828be38282e381aee381aee38081e3819de3828ce4bba5e9998de381afe381bee381a3e3819fe3818fe69bb8e38184e381a6e38184e381aae38184e381a8e38184e38186e4babae381afe5a49ae38184e38193e381a8e381a7e38197e38287e38186e380822020e38197e3818be38197e38081e69687e7aba0e4bd9ce68890e3818ce88ba6e6898be381aae4babae38284e38081e69687e7aba0e3818ce3828fe3818b000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
           end)}
        end
      )

      expected = %{
        name: long_token_name_shortened,
        decimals: 18,
        total_supply: 1_000_000_000_000_000_000,
        symbol: "BNT"
      }

      assert MetadataRetriever.get_functions_of(token) == expected
    end

    test "retries when some function gave error" do
      token = insert(:token, contract_address: build(:contract_address))

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 error: %{code: -32015, data: "something", message: "some error"},
                 id: id,
                 jsonrpc: "2.0"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
           end)}
        end
      )

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               }
           end)}
        end
      )

      expected = %{
        name: "Bancor",
        symbol: "BNT",
        total_supply: 1_000_000_000_000_000_000,
        decimals: 18
      }

      assert MetadataRetriever.get_functions_of(token) == expected
    end

    test "retries according to the configured number" do
      original = Application.get_env(:explorer, :token_functions_reader_max_retries)

      Application.put_env(:explorer, :token_functions_reader_max_retries, 2)

      token = insert(:token, contract_address: build(:contract_address))

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 error: %{code: -32015, data: "something", message: "some error"},
                 id: id,
                 jsonrpc: "2.0"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 error: %{code: -32015, data: "something", message: "some error"},
                 id: id,
                 jsonrpc: "2.0"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
           end)}
        end
      )

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 error: %{code: -32015, data: "something", message: "some error"},
                 id: id,
                 jsonrpc: "2.0"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 error: %{code: -32015, data: "something", message: "some error"},
                 id: id,
                 jsonrpc: "2.0"
               }
           end)}
        end
      )

      assert MetadataRetriever.get_functions_of(token) == %{
               name: "Bancor",
               total_supply: 1_000_000_000_000_000_000
             }

      on_exit(fn -> Application.put_env(:explorer, :token_functions_reader_max_retries, original) end)
    end
  end

  test "returns name and symbol when they are bytes32" do
    token = insert(:token, contract_address: build(:contract_address))

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      1,
      fn requests, _opts ->
        {:ok,
         Enum.map(requests, fn
           %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000012"
             }

           %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
             %{
               id: id,
               result: "0x4d616b6572000000000000000000000000000000000000000000000000000000"
             }

           %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
             %{
               id: id,
               result: "0x4d4b520000000000000000000000000000000000000000000000000000000000"
             }

           %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
             %{
               id: id,
               result: "0x00000000000000000000000000000000000000000000d3c21bcecceda1000000"
             }
         end)}
      end
    )

    expected = %{
      decimals: 18,
      name: "Maker",
      symbol: "MKR",
      total_supply: 1_000_000_000_000_000_000_000_000
    }

    assert MetadataRetriever.get_functions_of(token) == expected
  end

  describe "fetch_json/4" do
    setup do
      bypass = Bypass.open()

      on_exit(fn ->
        Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
      end)

      {:ok, bypass: bypass}
    end

    test "returns {:error, @no_uri_error} when empty uri is passed" do
      error = {:error, "no uri"}
      token_id = "TOKEN_ID"
      hex_token_id = "HEX_TOKEN_ID"
      from_base_uri = true

      result = MetadataRetriever.fetch_json({:ok, [""]}, token_id, hex_token_id, from_base_uri)

      assert result == error
    end

    test "returns {:error, @vm_execution_error} when 'execution reverted' error passed in uri" do
      uri_error = {:error, "something happened: execution reverted"}
      token_id = "TOKEN_ID"
      hex_token_id = "HEX_TOKEN_ID"
      from_base_uri = true
      result_error = {:error, "VM execution error"}

      result = MetadataRetriever.fetch_json(uri_error, token_id, hex_token_id, from_base_uri)

      assert result == result_error
    end

    test "returns {:error, @vm_execution_error} when 'VM execution error' error passed in uri" do
      error = {:error, "VM execution error"}
      token_id = "TOKEN_ID"
      hex_token_id = "HEX_TOKEN_ID"
      from_base_uri = true

      result = MetadataRetriever.fetch_json(error, token_id, hex_token_id, from_base_uri)

      assert result == error
    end

    test "returns {:error, error} when all other errors passed in uri" do
      error = {:error, "Some error"}
      token_id = "TOKEN_ID"
      hex_token_id = "HEX_TOKEN_ID"
      from_base_uri = true

      result = MetadataRetriever.fetch_json(error, token_id, hex_token_id, from_base_uri)

      assert result == error
    end

    test "returns {:error, truncated_error} when long error passed in uri" do
      error =
        {:error,
         "ERROR: Unable to establish a connection to the database server. The database server may be offline, or there could be a network issue preventing access. Please ensure that the database server is running and that the network configuration is correct. Additionally, check the database credentials and permissions to ensure they are valid. If the issue persists, contact your system administrator for further assistance. Error code: DB_CONN_FAILED_101234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890"}

      token_id = "TOKEN_ID"
      hex_token_id = "HEX_TOKEN_ID"
      from_base_uri = true

      truncated_error =
        {:error,
         "ERROR: Unable to establish a connection to the database server. The database server may be offline, or there could be a network issue preventing access. Please ensure that the database server is running and that the network configuration is correct. Ad..."}

      result = MetadataRetriever.fetch_json(error, token_id, hex_token_id, from_base_uri)

      assert result == truncated_error
    end

    test "Constructs IPFS link with query param" do
      configuration = Application.get_env(:indexer, :ipfs)

      Application.put_env(:indexer, :ipfs,
        gateway_url: Keyword.get(configuration, :gateway_url),
        gateway_url_param_location: :query,
        gateway_url_param_key: "x-apikey",
        gateway_url_param_value: "mykey"
      )

      data = "QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"

      result = %{
        "name" => "asda",
        "description" => "asda",
        "salePrice" => 34,
        "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
        "collectionId" => "1871_1665123820823"
      }

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: "https://ipfs.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP?x-apikey=mykey"},
                    _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(result)
           }}
        end
      )

      assert {:ok,
              %{
                metadata: %{
                  "collectionId" => "1871_1665123820823",
                  "description" => "asda",
                  "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
                  "name" => "asda",
                  "salePrice" => 34
                }
              }} == MetadataRetriever.fetch_json({:ok, [data]})

      Application.put_env(:indexer, :ipfs, configuration)
    end

    test "Constructs IPFS link with no query param, if gateway_url_param_location is invalid" do
      configuration = Application.get_env(:indexer, :ipfs)

      Application.put_env(:indexer, :ipfs,
        gateway_url: Keyword.get(configuration, :gateway_url),
        gateway_url_param_location: :query2,
        gateway_url_param_key: "x-apikey",
        gateway_url_param_value: "mykey"
      )

      data = "QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"

      result = %{
        "name" => "asda",
        "description" => "asda",
        "salePrice" => 34,
        "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
        "collectionId" => "1871_1665123820823"
      }

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: "https://ipfs.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(result)
           }}
        end
      )

      assert {:ok,
              %{
                metadata: %{
                  "collectionId" => "1871_1665123820823",
                  "description" => "asda",
                  "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
                  "name" => "asda",
                  "salePrice" => 34
                }
              }} == MetadataRetriever.fetch_json({:ok, [data]})

      Application.put_env(:indexer, :ipfs, configuration)
    end

    test "Constructs IPFS link with additional header" do
      configuration = Application.get_env(:indexer, :ipfs)

      Application.put_env(:indexer, :ipfs,
        gateway_url: Keyword.get(configuration, :gateway_url),
        gateway_url_param_location: :header,
        gateway_url_param_key: "x-apikey",
        gateway_url_param_value: "mykey"
      )

      data = "QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"

      result = %{
        "name" => "asda",
        "description" => "asda",
        "salePrice" => 34,
        "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
        "collectionId" => "1871_1665123820823"
      }

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{
                      url: "https://ipfs.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP",
                      headers: [{"x-apikey", "mykey"}, {"User-Agent", _}]
                    },
                    _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(result)
           }}
        end
      )

      assert {:ok,
              %{
                metadata: %{
                  "collectionId" => "1871_1665123820823",
                  "description" => "asda",
                  "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
                  "name" => "asda",
                  "salePrice" => 34
                }
              }} == MetadataRetriever.fetch_json({:ok, [data]})

      Application.put_env(:indexer, :ipfs, configuration)
    end

    test "fetches json with latin1 encoding", %{bypass: bypass} do
      path = "/api/card/55265"

      json = """
      {
        "name": "Sérgio Mendonça"
      }
      """

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      url = "http://localhost:#{bypass.port}#{path}"

      assert {:ok_store_uri, %{metadata: %{"name" => "Sérgio Mendonça"}}, url} ==
               MetadataRetriever.fetch_json({:ok, [url]})
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

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      url = "http://localhost:#{bypass.port}#{path}"

      {:ok_store_uri, %{metadata: metadata}, ^url} =
        MetadataRetriever.fetch_metadata_from_uri(url, [])

      assert Map.get(metadata, "attributes") == Jason.decode!(attributes)
    end

    test "decodes json file in tokenURI" do
      data =
        {:ok,
         [
           "data:application/json,{\"name\":\"Home%20Address%20-%200x0000000000C1A6066c6c8B9d63e9B6E8865dC117\",\"description\":\"This%20NFT%20can%20be%20redeemed%20on%20HomeWork%20to%20grant%20a%20controller%20the%20exclusive%20right%20to%20deploy%20contracts%20with%20arbitrary%20bytecode%20to%20the%20designated%20home%20address.\",\"image\":\"data:image/svg+xml;charset=utf-8;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNDQgNzIiPjxzdHlsZT48IVtDREFUQVsuQntzdHJva2UtbGluZWpvaW46cm91bmR9LkN7c3Ryb2tlLW1pdGVybGltaXQ6MTB9LkR7c3Ryb2tlLXdpZHRoOjJ9LkV7ZmlsbDojOWI5YjlhfS5Ge3N0cm9rZS1saW5lY2FwOnJvdW5kfV1dPjwvc3R5bGU+PGcgdHJhbnNmb3JtPSJtYXRyaXgoMS4wMiAwIDAgMS4wMiA4LjEgMCkiPjxwYXRoIGZpbGw9IiNmZmYiIGQ9Ik0xOSAzMmgzNHYyNEgxOXoiLz48ZyBzdHJva2U9IiMwMDAiIGNsYXNzPSJCIEMgRCI+PHBhdGggZmlsbD0iI2E1NzkzOSIgZD0iTTI1IDQwaDl2MTZoLTl6Ii8+PHBhdGggZmlsbD0iIzkyZDNmNSIgZD0iTTQwIDQwaDh2N2gtOHoiLz48cGF0aCBmaWxsPSIjZWE1YTQ3IiBkPSJNNTMgMzJIMTl2LTFsMTYtMTYgMTggMTZ6Ii8+PHBhdGggZmlsbD0ibm9uZSIgZD0iTTE5IDMyaDM0djI0SDE5eiIvPjxwYXRoIGZpbGw9IiNlYTVhNDciIGQ9Ik0yOSAyMWwtNSA1di05aDV6Ii8+PC9nPjwvZz48ZyB0cmFuc2Zvcm09Im1hdHJpeCguODQgMCAwIC44NCA2NSA1KSI+PHBhdGggZD0iTTkuNSAyMi45bDQuOCA2LjRhMy4xMiAzLjEyIDAgMCAxLTMgMi4ybC00LjgtNi40Yy4zLTEuNCAxLjYtMi40IDMtMi4yeiIgZmlsbD0iI2QwY2ZjZSIvPjxwYXRoIGZpbGw9IiMwMTAxMDEiIGQ9Ik00MS43IDM4LjVsNS4xLTYuNSIvPjxwYXRoIGQ9Ik00Mi45IDI3LjhMMTguNCA1OC4xIDI0IDYybDIxLjgtMjcuMyAyLjMtMi44eiIgY2xhc3M9IkUiLz48cGF0aCBmaWxsPSIjMDEwMTAxIiBkPSJNNDMuNCAyOS4zbC00LjcgNS44Ii8+PHBhdGggZD0iTTQ2LjggMzJjMy4yIDIuNiA4LjcgMS4yIDEyLjEtMy4yczMuNi05LjkuMy0xMi41bC01LjEgNi41LTIuOC0uMS0uNy0yLjcgNS4xLTYuNWMtMy4yLTIuNi04LjctMS4yLTEyLjEgMy4ycy0zLjYgOS45LS4zIDEyLjUiIGNsYXNzPSJFIi8+PHBhdGggZmlsbD0iI2E1NzkzOSIgZD0iTTI3LjMgMjZsMTEuOCAxNS43IDMuNCAyLjQgOS4xIDE0LjQtMy4yIDIuMy0xIC43LTEwLjItMTMuNi0xLjMtMy45LTExLjgtMTUuN3oiLz48cGF0aCBkPSJNMTIgMTkuOWw1LjkgNy45IDEwLjItNy42LTMuNC00LjVzNi44LTUuMSAxMC43LTQuNWMwIDAtNi42LTMtMTMuMyAxLjFTMTIgMTkuOSAxMiAxOS45eiIgY2xhc3M9IkUiLz48ZyBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAiIGNsYXNzPSJCIEMgRCI+PHBhdGggZD0iTTUyIDU4LjlMNDAuOSA0My4ybC0zLjEtMi4zLTEwLjYtMTQuNy0yLjkgMi4yIDEwLjYgMTQuNyAxLjEgMy42IDExLjUgMTUuNXpNMTIuNSAxOS44bDUuOCA4IDEwLjMtNy40LTMuMy00LjZzNi45LTUgMTAuOC00LjNjMCAwLTYuNi0zLjEtMTMuMy45cy0xMC4zIDcuNC0xMC4zIDcuNHptLTIuNiAyLjlsNC43IDYuNWMtLjUgMS4zLTEuNyAyLjEtMyAyLjJsLTQuNy02LjVjLjMtMS40IDEuNi0yLjQgMy0yLjJ6Ii8+PHBhdGggZD0iTTQxLjMgMzguNWw1LjEtNi41bS0zLjUtMi43bC00LjYgNS44bTguMS0zLjFjMy4yIDIuNiA4LjcgMS4yIDEyLjEtMy4yczMuNi05LjkuMy0xMi41bC01LjEgNi41LTIuOC0uMS0uOC0yLjcgNS4xLTYuNWMtMy4yLTIuNi04LjctMS4yLTEyLjEgMy4yLTMuNCA0LjMtMy42IDkuOS0uMyAxMi41IiBjbGFzcz0iRiIvPjxwYXRoIGQ9Ik0zMC44IDQ0LjRMMTkgNTguOWw0IDMgMTAtMTIuNyIgY2xhc3M9IkYiLz48L2c+PC9nPjwvc3ZnPg==\"}"
         ]}

      assert MetadataRetriever.fetch_json(data) ==
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
      data =
        {:ok,
         [
           "data:application/json;base64,eyJuYW1lIjogIi54ZGFpIiwgImRlc2NyaXB0aW9uIjogIlB1bmsgRG9tYWlucyBkaWdpdGFsIGlkZW50aXR5LiBWaXNpdCBodHRwczovL3B1bmsuZG9tYWlucy8iLCAiaW1hZ2UiOiAiZGF0YTppbWFnZS9zdmcreG1sO2Jhc2U2NCxQSE4yWnlCNGJXeHVjejBpYUhSMGNEb3ZMM2QzZHk1M015NXZjbWN2TWpBd01DOXpkbWNpSUhacFpYZENiM2c5SWpBZ01DQTFNREFnTlRBd0lpQjNhV1IwYUQwaU5UQXdJaUJvWldsbmFIUTlJalV3TUNJK1BHUmxabk0rUEd4cGJtVmhja2R5WVdScFpXNTBJR2xrUFNKbmNtRmtJaUI0TVQwaU1DVWlJSGt4UFNJd0pTSWdlREk5SWpFd01DVWlJSGt5UFNJd0pTSStQSE4wYjNBZ2IyWm1jMlYwUFNJd0pTSWdjM1I1YkdVOUluTjBiM0F0WTI5c2IzSTZjbWRpS0RVNExERTNMREV4TmlrN2MzUnZjQzF2Y0dGamFYUjVPakVpSUM4K1BITjBiM0FnYjJabWMyVjBQU0l4TURBbElpQnpkSGxzWlQwaWMzUnZjQzFqYjJ4dmNqcHlaMklvTVRFMkxESTFMREUzS1R0emRHOXdMVzl3WVdOcGRIazZNU0lnTHo0OEwyeHBibVZoY2tkeVlXUnBaVzUwUGp3dlpHVm1jejQ4Y21WamRDQjRQU0l3SWlCNVBTSXdJaUIzYVdSMGFEMGlOVEF3SWlCb1pXbG5hSFE5SWpVd01DSWdabWxzYkQwaWRYSnNLQ05uY21Ga0tTSXZQangwWlhoMElIZzlJalV3SlNJZ2VUMGlOVEFsSWlCa2IyMXBibUZ1ZEMxaVlYTmxiR2x1WlQwaWJXbGtaR3hsSWlCbWFXeHNQU0ozYUdsMFpTSWdkR1Y0ZEMxaGJtTm9iM0k5SW0xcFpHUnNaU0lnWm05dWRDMXphWHBsUFNKNExXeGhjbWRsSWo0dWVHUmhhVHd2ZEdWNGRENDhkR1Y0ZENCNFBTSTFNQ1VpSUhrOUlqY3dKU0lnWkc5dGFXNWhiblF0WW1GelpXeHBibVU5SW0xcFpHUnNaU0lnWm1sc2JEMGlkMmhwZEdVaUlIUmxlSFF0WVc1amFHOXlQU0p0YVdSa2JHVWlQbkIxYm1zdVpHOXRZV2x1Y3p3dmRHVjRkRDQ4TDNOMlp6ND0ifQ=="
         ]}

      assert MetadataRetriever.fetch_json(data) ==
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
      data =
        {:ok,
         [
           "data:application/json;base64,eyJkZXNjcmlwdGlvbiI6ICJQdW5rIERvbWFpbnMgZGlnaXRhbCBpZGVudGl0eSDDry4gVmlzaXQgaHR0cHM6Ly9wdW5rLmRvbWFpbnMvIn0="
         ]}

      assert MetadataRetriever.fetch_json(data) ==
               {:ok,
                %{
                  metadata: %{
                    "description" => "Punk Domains digital identity ï. Visit https://punk.domains/"
                  }
                }}
    end

    test "fetches image from ipfs link directly" do
      path = "/ipfs/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"

      json = """
      {
        "image": "https://ipfs.io/ipfs/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"
      }
      """

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: "https://ipfs.io/ipfs/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: json
           }}
        end
      )

      data =
        {:ok,
         [
           path
         ]}

      assert {:ok,
              %{
                metadata: %{
                  "image" => "https://ipfs.io/ipfs/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"
                }
              }} == MetadataRetriever.fetch_json(data)
    end

    test "Fetches metadata from ipfs" do
      path = "/ipfs/bafybeid4ed2ua7fwupv4nx2ziczr3edhygl7ws3yx6y2juon7xakgj6cfm/51.json"

      json = """
      {
        "image": "ipfs://bafybeihxuj3gxk7x5p36amzootyukbugmx3pw7dyntsrohg3se64efkuga/51.png"
      }
      """

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: "https://ipfs.io/ipfs/bafybeid4ed2ua7fwupv4nx2ziczr3edhygl7ws3yx6y2juon7xakgj6cfm/51.json"},
                    _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: json
           }}
        end
      )

      data =
        {:ok,
         [
           path
         ]}

      {:ok,
       %{
         metadata: metadata
       }} = MetadataRetriever.fetch_json(data)

      assert "ipfs://bafybeihxuj3gxk7x5p36amzootyukbugmx3pw7dyntsrohg3se64efkuga/51.png" == Map.get(metadata, "image")
    end

    test "Fetches metadata from '${url}'", %{bypass: bypass} do
      path = "/data/8/8578.json"
      url = "http://localhost:#{bypass.port}#{path}"

      data =
        {:ok,
         [
           "'#{url}'"
         ]}

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

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      assert {:ok_store_uri,
              %{
                metadata: Jason.decode!(json)
              }, url} == MetadataRetriever.fetch_json(data)
    end

    test "Process custom execution reverted" do
      data =
        {:error,
         "(3) execution reverted: Nonexistent token (0x08c379a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000114e6f6e6578697374656e7420746f6b656e000000000000000000000000000000)"}

      assert {:error, "VM execution error"} == MetadataRetriever.fetch_json(data)
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

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: "https://ipfs.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(result)
           }}
        end
      )

      assert {:ok,
              %{
                metadata: %{
                  "collectionId" => "1871_1665123820823",
                  "description" => "asda",
                  "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
                  "name" => "asda",
                  "salePrice" => 34
                }
              }} == MetadataRetriever.fetch_json({:ok, [data]})
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

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      url = "http://localhost:#{bypass.port}#{path}"

      assert {:ok_store_uri,
              %{
                metadata: Jason.decode!(json)
              },
              url} ==
               MetadataRetriever.fetch_json({:ok, [url]})
    end
  end

  describe "ipfs_link/1" do
    test "returns correct ipfs link for given data" do
      data = "QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"
      expected_link = "https://ipfs.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"

      assert MetadataRetriever.ipfs_link(data) == expected_link
    end

    test "returns correct ipfs link for given data at public IPFS gateway URL" do
      original = Application.get_env(:indexer, :ipfs)

      Application.put_env(:indexer, :ipfs,
        gateway_url: "https://ipfs.io/ipfs/",
        public_gateway_url: "https://public_ipfs_gateway.io/ipfs/"
      )

      data = "QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"
      expected_link = "https://public_ipfs_gateway.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"

      assert MetadataRetriever.ipfs_link(data, true) == expected_link

      Application.put_env(:indexer, :ipfs, original)
    end

    test "returns correct ipfs link for given data with IPFS gateway params" do
      original = Application.get_env(:indexer, :ipfs)

      Application.put_env(:indexer, :ipfs,
        gateway_url: "https://ipfs.io/ipfs/",
        gateway_url_param_key: "user",
        gateway_url_param_value: "pass",
        gateway_url_param_location: :query
      )

      data = "QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"
      expected_link = "https://ipfs.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP?user=pass"

      assert MetadataRetriever.ipfs_link(data) == expected_link

      Application.put_env(:indexer, :ipfs, original)
    end

    test "returns correct ipfs link for empty data" do
      data = ""
      expected_link = "https://ipfs.io/ipfs/"

      assert MetadataRetriever.ipfs_link(data) == expected_link
    end

    test "returns correct ipfs link for nil data" do
      data = nil
      expected_link = "https://ipfs.io/ipfs/"

      assert MetadataRetriever.ipfs_link(data) == expected_link
    end

    test "returns correct ipfs link for data with special characters" do
      data = "data_with_special_chars!@#$%^&*()"
      expected_link = "https://ipfs.io/ipfs/data_with_special_chars!@#$%^&*()"

      assert MetadataRetriever.ipfs_link(data) == expected_link
    end
  end

  describe "arweave_link/1" do
    test "returns correct arweave link for given data" do
      data = "some_arweave_data"
      expected_link = "https://arweave.net/some_arweave_data"

      assert MetadataRetriever.arweave_link(data) == expected_link
    end

    test "returns correct arweave link for empty data" do
      data = ""
      expected_link = "https://arweave.net/"

      assert MetadataRetriever.arweave_link(data) == expected_link
    end

    test "returns correct arweave link for nil data" do
      data = nil
      expected_link = "https://arweave.net/"

      assert MetadataRetriever.arweave_link(data) == expected_link
    end

    test "returns correct arweave link for data with special characters" do
      data = "data_with_special_chars!@#$%^&*()"
      expected_link = "https://arweave.net/data_with_special_chars!@#$%^&*()"

      assert MetadataRetriever.arweave_link(data) == expected_link
    end
  end
end
