defmodule BlockScoutWeb.TransactionStateControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  import BlockScoutWeb.WebRouter.Helpers, only: [transaction_state_path: 3]
  import BlockScoutWeb.WeiHelpers, only: [format_wei_value: 2]
  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  alias Explorer.Chain.Wei
  alias EthereumJSONRPC.Blocks

  describe "GET index/3" do
    test "loads existing transaction", %{conn: conn} do
      transaction = insert(:transaction)
      conn = get(conn, transaction_state_path(conn, :index, transaction.hash))

      assert html_response(conn, 200)
    end

    test "with missing transaction", %{conn: conn} do
      hash = transaction_hash()
      conn = get(conn, transaction_state_path(BlockScoutWeb.Endpoint, :index, hash))

      assert html_response(conn, 404)
    end

    test "with invalid transaction hash", %{conn: conn} do
      conn = get(conn, transaction_state_path(BlockScoutWeb.Endpoint, :index, "nope"))

      assert html_response(conn, 422)
    end

    test "returns fetched state changes for the transaction with token transfer", %{conn: conn} do
      block = insert(:block)
      address_a = insert(:address)
      address_b = insert(:address)
      token = insert(:token, type: "ERC-20")

      insert(:fetched_balance,
        address_hash: address_a.hash,
        value: 1_000_000_000_000_000_000,
        block_number: block.number
      )

      insert(:fetched_balance,
        address_hash: address_b.hash,
        value: 2_000_000_000_000_000_000,
        block_number: block.number
      )

      transaction =
        :transaction
        |> insert(from_address: address_a, to_address: address_b, value: 1000)
        |> with_block(status: :ok)

      insert(:fetched_balance,
        address_hash: transaction.block.miner_hash,
        value: 2_500_000,
        block_number: block.number
      )

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          token: token,
          token_contract_address: token.contract_address
        )

      insert(
        :token_balance,
        address: token_transfer.from_address,
        token: token,
        token_contract_address_hash: token.contract_address_hash,
        value: 3_000_000,
        block_number: block.number
      )

      insert(
        :token_balance,
        address: token_transfer.to_address,
        token: token,
        token_contract_address_hash: token.contract_address_hash,
        value: 1000,
        block_number: block.number
      )

      conn = get(conn, transaction_state_path(conn, :index, transaction), %{type: "JSON"})

      {:ok, %{"items" => items}} = conn.resp_body |> Poison.decode()
      full_text = Enum.join(items)

      assert(String.contains?(full_text, format_wei_value(%Wei{value: Decimal.new(1, 1, 18)}, :ether)))

      assert(String.contains?(full_text, format_wei_value(%Wei{value: Decimal.new(1, 2, 18)}, :ether)))

      assert(length(items) == 5)
    end

    test "fetch coin balances if needed", %{conn: conn} do
      EthereumJSONRPC.Mox
      |> stub(:json_rpc, fn
        [%{id: id, method: "eth_getBalance", params: _}], _options ->
          {:ok, [%{id: id, result: integer_to_quantity(123)}]}

        [%{id: id, method: "eth_getBlockByNumber", params: _}], _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "author" => "0x0000000000000000000000000000000000000000",
                 "difficulty" => "0x20000",
                 "extraData" => "0x",
                 "gasLimit" => "0x663be0",
                 "gasUsed" => "0x0",
                 "hash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "miner" => "0x0000000000000000000000000000000000000000",
                 "number" => integer_to_quantity(1),
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
           ]}
      end)

      insert(:block)
      insert(:block)
      address_a = insert(:address)
      address_b = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address_a, to_address: address_b, value: 1000)
        |> with_block(status: :ok)

      conn = get(conn, transaction_state_path(conn, :index, transaction), %{type: "JSON"})

      {:ok, %{"items" => items}} = conn.resp_body |> Poison.decode()
      full_text = Enum.join(items)

      assert(String.contains?(full_text, format_wei_value(%Wei{value: Decimal.new(123)}, :ether)))
      assert(length(items) == 3)
    end
  end
end
