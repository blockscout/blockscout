defmodule Indexer.Token.FetcherTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Indexer.Token.Fetcher

  setup :verify_on_exit!

  describe "init/3" do
    test "returns uncataloged tokens", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      insert(:token, cataloged: true)
      %Token{contract_address_hash: uncatalog_address} = insert(:token, cataloged: false)

      assert Fetcher.init([], &[&1 | &2], json_rpc_named_arguments) == [uncatalog_address]
    end
  end

  describe "run/3" do
    test "skips tokens that have already been cataloged", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      expect(EthereumJSONRPC.Mox, :json_rpc, 0, fn _, _ -> :ok end)
      %Token{contract_address_hash: contract_address_hash} = insert(:token, cataloged: true)
      assert Fetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok
    end

    test "catalogs tokens that haven't been cataloged", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          1,
          fn [%{id: "decimals"}, %{id: "name"}, %{id: "symbol"}, %{id: "totalSupply"}], _opts ->
            {:ok,
             [
               %{
                 id: "decimals",
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               },
               %{
                 id: "name",
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
               },
               %{
                 id: "symbol",
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               },
               %{
                 id: "totalSupply",
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
             ]}
          end
        )

        assert Fetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok

        expected_supply = Decimal.new(1_000_000_000_000_000_000)

        assert {:ok,
                %Token{
                  name: "Bancor",
                  symbol: "BNT",
                  total_supply: ^expected_supply,
                  decimals: 18,
                  cataloged: true
                }} = Chain.token_from_address_hash(contract_address_hash)
      end
    end

    test "considers the contract address formatted hash when it is an invalid string", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          1,
          fn [%{id: "decimals"}, %{id: "name"}, %{id: "symbol"}, %{id: "totalSupply"}], _opts ->
            {:ok,
             [
               %{
                 id: "decimals",
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               },
               %{
                 id: "name",
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001aa796568616e7a652067676761202075797575206e6e6e6e6e200000000000000"
               },
               %{
                 id: "symbol",
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               },
               %{
                 id: "totalSupply",
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
             ]}
          end
        )

        assert Fetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok
        assert {:ok, %Token{cataloged: true, name: "0x0000"}} = Chain.token_from_address_hash(contract_address_hash)
      end
    end

    test "considers the decimals nil when it is too large a number", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          1,
          fn [%{id: "decimals"}, %{id: "name"}, %{id: "symbol"}, %{id: "totalSupply"}], _opts ->
            {:ok,
             [
               %{
                 id: "decimals",
                 result: "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
               },
               %{
                 id: "name",
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               },
               %{
                 id: "symbol",
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               },
               %{
                 id: "totalSupply",
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
             ]}
          end
        )

        assert Fetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok
        assert {:ok, %Token{cataloged: true, decimals: nil}} = Chain.token_from_address_hash(contract_address_hash)
      end
    end

    test "considers the symbol nil when it is an invalid string", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          1,
          fn [%{id: "decimals"}, %{id: "name"}, %{id: "symbol"}, %{id: "totalSupply"}], _opts ->
            {:ok,
             [
               %{
                 id: "decimals",
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               },
               %{
                 id: "name",
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               },
               %{
                 id: "symbol",
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001aa796568616e7a652067676761202075797575206e6e6e6e6e200000000000000"
               },
               %{
                 id: "totalSupply",
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
             ]}
          end
        )

        assert Fetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok
        assert {:ok, %Token{cataloged: true, symbol: nil}} = Chain.token_from_address_hash(contract_address_hash)
      end
    end

    test "considers name as nil when the name is nil", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          1,
          fn [%{id: "decimals"}, %{id: "name"}, %{id: "symbol"}, %{id: "totalSupply"}], _opts ->
            {:ok,
             [
               %{
                 id: "decimals",
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               },
               %{
                 id: "symbol",
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001aa796568616e7a652067676761202075797575206e6e6e6e6e200000000000000"
               },
               %{
                 id: "totalSupply",
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
             ]}
          end
        )

        assert Fetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok
        assert {:ok, %Token{cataloged: true, name: nil}} = Chain.token_from_address_hash(contract_address_hash)
      end
    end

    test "shortens strings larger than 255 characters", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      long_token_name_shortened =
        "<button class=\"navbar-toggler\" type=\"button\" data-toggle=\"collapse\" data-target=\"#navbarSupportedContent\" aria-controls=\"navbarSupportedContent\" aria-expanded=\"false\" aria-label=\"<%= gettext(\"Toggle navigation\") %>\"> <span class=\"navbar-toggler-icon\"></sp"

      token = insert(:token, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          1,
          fn [%{id: "decimals"}, %{id: "name"}, %{id: "symbol"}, %{id: "totalSupply"}], _opts ->
            {:ok,
             [
               %{
                 id: "name",
                 # this is how the token name would come from the blockchain unshortened.
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000010c3c627574746f6e20636c6173733d226e61766261722d746f67676c65722220747970653d22627574746f6e2220646174612d746f67676c653d22636f6c6c617073652220646174612d7461726765743d22236e6176626172537570706f72746564436f6e74656e742220617269612d636f6e74726f6c733d226e6176626172537570706f72746564436f6e74656e742220617269612d657870616e6465643d2266616c73652220617269612d6c6162656c3d223c253d20676574746578742822546f67676c65206e617669676174696f6e222920253e223e203c7370616e20636c6173733d226e61766261722d746f67676c65722d69636f6e223e3c2f7370616e3e203c2f627574746f6e3e0000000000000000000000000000000000000000"
               }
             ]}
          end
        )

        assert Fetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok

        assert {:ok, %Token{cataloged: true, name: ^long_token_name_shortened}} =
                 Chain.token_from_address_hash(contract_address_hash)
      end
    end
  end
end
