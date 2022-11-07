defmodule Indexer.Fetcher.TokenInstanceTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Repo
  alias Indexer.Fetcher.TokenInstance

  describe "run/2" do
    test "updates current token balance" do
      token = insert(:token, type: "ERC-1155")
      token_contract_address_hash = token.contract_address_hash
      instance = insert(:token_instance, token_contract_address_hash: token_contract_address_hash)
      token_id = instance.token_id
      address = insert(:address, hash: "0x57e93bb58268de818b42e3795c97bad58afcd3fe")
      address_hash = address.hash

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: 0, method: "eth_call", params: [%{data: "0xc87b56dd" <> _}, _]}], _ ->
        {:ok,
         [
           %{
             id: 0,
             result:
               "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000027b7d000000000000000000000000000000000000000000000000000000000000"
           }
         ]}
      end)
      |> expect(:json_rpc, fn [%{id: 0, method: "eth_call", params: [%{data: "0x6352211e" <> _}, _]}], _ ->
        {:ok, [%{id: 0, result: "0x00000000000000000000000057e93bb58268de818b42e3795c97bad58afcd3fe"}]}
      end)

      TokenInstance.run(
        [%{contract_address_hash: token_contract_address_hash, token_id: token_id}],
        nil
      )

      assert %{
               token_id: ^token_id,
               token_type: "ERC-1155",
               token_contract_address_hash: ^token_contract_address_hash,
               address_hash: ^address_hash
             } = Repo.one(CurrentTokenBalance)
    end

    test "updates current token balance with missing address" do
      token = insert(:token, type: "ERC-1155")
      token_contract_address_hash = token.contract_address_hash
      instance = insert(:token_instance, token_contract_address_hash: token_contract_address_hash)
      token_id = instance.token_id
      {:ok, address_hash} = Chain.string_to_address_hash("0x57e93bb58268de818b42e3795c97bad58afcd3fe")

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: 0, method: "eth_call", params: [%{data: "0xc87b56dd" <> _}, _]}], _ ->
        {:ok,
         [
           %{
             id: 0,
             result:
               "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000027b7d000000000000000000000000000000000000000000000000000000000000"
           }
         ]}
      end)
      |> expect(:json_rpc, fn [%{id: 0, method: "eth_call", params: [%{data: "0x6352211e" <> _}, _]}], _ ->
        {:ok, [%{id: 0, result: "0x00000000000000000000000057e93bb58268de818b42e3795c97bad58afcd3fe"}]}
      end)

      TokenInstance.run(
        [%{contract_address_hash: token_contract_address_hash, token_id: token_id}],
        nil
      )

      assert %{
               token_id: ^token_id,
               token_type: "ERC-1155",
               token_contract_address_hash: ^token_contract_address_hash,
               address_hash: ^address_hash
             } = Repo.one(CurrentTokenBalance)

      assert %Address{} = Repo.get_by(Address, hash: address_hash)
    end
  end
end
