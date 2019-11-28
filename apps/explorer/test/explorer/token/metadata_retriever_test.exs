defmodule Explorer.Token.MetadataRetrieverTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  alias Explorer.Token.MetadataRetriever

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

      assert MetadataRetriever.get_functions_of(token.contract_address_hash) == expected
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
              ]} = MetadataRetriever.get_functions_of([token.contract_address_hash, token.contract_address_hash])
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

      assert MetadataRetriever.get_functions_of(token.contract_address_hash) == expected
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

      assert MetadataRetriever.get_functions_of(token.contract_address_hash) == expected
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

      assert MetadataRetriever.get_functions_of(token.contract_address_hash) == expected

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

      assert MetadataRetriever.get_functions_of(token.contract_address_hash) == expected
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

      assert MetadataRetriever.get_functions_of(token.contract_address_hash) == expected
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

      assert MetadataRetriever.get_functions_of(token.contract_address_hash) == %{
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

    assert MetadataRetriever.get_functions_of(token.contract_address_hash) == expected
  end
end
