defmodule Explorer.Chain.Address.TransactionsTest do
  use Explorer.DataCase

  alias Explorer.Chain.CsvExport.Address.Transactions, as: AddressTransactionsCsvExporter
  alias Explorer.Chain.Wei

  describe "export/3" do
    test "exports address transactions to csv" do
      address = insert(:address)

      insert(:contract_method,
        identifier: Base.decode16!("731133e9", case: :lower),
        abi: %{
          "constant" => false,
          "inputs" => [
            %{"name" => "account", "type" => "address"},
            %{"name" => "id", "type" => "uint256"},
            %{"name" => "amount", "type" => "uint256"},
            %{"name" => "data", "type" => "bytes"}
          ],
          "name" => "mint",
          "outputs" => [],
          "payable" => false,
          "stateMutability" => "nonpayable",
          "type" => "function"
        }
      )

      to_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(
          from_address: address,
          to_address: to_address,
          input:
            "0x731133e9000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001700000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000"
        )
        |> with_block()
        |> Repo.preload(:token_transfers)

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      [result] =
        address.hash
        |> AddressTransactionsCsvExporter.export(from_period, to_period, [])
        |> Enum.to_list()
        |> Enum.drop(1)
        |> Enum.map(fn [
                         [[], hash],
                         _,
                         [[], block_number],
                         _,
                         [[], timestamp],
                         _,
                         [[], from_address],
                         _,
                         [[], to_address],
                         _,
                         [[], created_address],
                         _,
                         [[], type],
                         _,
                         [[], value],
                         _,
                         [[], fee],
                         _,
                         [[], status],
                         _,
                         [[], error],
                         _,
                         [[], cur_price],
                         _,
                         [[], op_price],
                         _,
                         [[], cl_price],
                         _,
                         [[], method_name],
                         _
                       ] ->
          %{
            hash: hash,
            block_number: block_number,
            timestamp: timestamp,
            from_address: from_address,
            to_address: to_address,
            created_address: created_address,
            type: type,
            value: value,
            fee: fee,
            status: status,
            error: error,
            current_price: cur_price,
            opening_price: op_price,
            closing_price: cl_price,
            method_name: method_name
          }
        end)

      assert result.block_number == to_string(transaction.block_number)
      assert result.timestamp
      assert result.created_address == to_string(transaction.created_contract_address_hash)
      assert result.from_address == to_string(transaction.from_address)
      assert result.to_address == to_string(transaction.to_address)
      assert result.hash == to_string(transaction.hash)
      assert result.type == "OUT"
      assert result.value == transaction.value |> Wei.to(:wei) |> to_string()
      assert result.fee
      assert result.status == to_string(transaction.status)
      assert result.error == to_string(transaction.error)
      assert result.current_price
      assert result.opening_price
      assert result.closing_price
      assert result.method_name == "mint"
    end

    test "fetches all transactions" do
      address = insert(:address)

      1..200
      |> Enum.map(fn _ ->
        :transaction
        |> insert(from_address: address)
        |> with_block()
      end)
      |> Enum.count()

      1..200
      |> Enum.map(fn _ ->
        :transaction
        |> insert(to_address: address)
        |> with_block()
      end)
      |> Enum.count()

      1..200
      |> Enum.map(fn _ ->
        :transaction
        |> insert(created_contract_address: address)
        |> with_block()
      end)
      |> Enum.count()

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      result =
        address.hash
        |> AddressTransactionsCsvExporter.export(from_period, to_period, [])
        |> Enum.to_list()
        |> Enum.drop(1)

      assert Enum.count(result) == 600
    end
  end
end
