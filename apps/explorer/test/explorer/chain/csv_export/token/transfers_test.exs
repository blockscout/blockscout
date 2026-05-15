# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.CsvExport.Token.TransfersTest do
  use Explorer.DataCase

  alias Explorer.Chain.Address
  alias Explorer.Chain.CsvExport.Token.Transfers, as: TokenTransfersExporter

  setup do
    original_limit = Application.get_env(:explorer, :csv_export_limit)
    Application.put_env(:explorer, :csv_export_limit, 150)

    on_exit(fn ->
      if original_limit do
        Application.put_env(:explorer, :csv_export_limit, original_limit)
      else
        Application.delete_env(:explorer, :csv_export_limit)
      end
    end)

    {:ok, now} = DateTime.now("Etc/UTC")
    from_period = DateTime.add(now, -1, :day) |> DateTime.to_iso8601()
    to_period = DateTime.add(now, 1, :day) |> DateTime.to_iso8601()

    {:ok, %{from_period: from_period, to_period: to_period}}
  end

  describe "export/6" do
    test "exports token transfers to csv with header and transfer rows", %{
      from_period: from_period,
      to_period: to_period
    } do
      token = insert(:token, type: "ERC-20", decimals: 18, symbol: "TKN")

      transaction1 =
        :transaction
        |> insert()
        |> with_block()

      transfer1 =
        insert(:token_transfer,
          transaction: transaction1,
          token_contract_address: token.contract_address,
          token_type: "ERC-20",
          block_number: transaction1.block_number,
          amount: Decimal.new(1_000)
        )

      transaction2 =
        :transaction
        |> insert()
        |> with_block()

      transfer2 =
        insert(:token_transfer,
          transaction: transaction2,
          token_contract_address: token.contract_address,
          token_type: "ERC-20",
          block_number: transaction2.block_number,
          amount: Decimal.new(2_000)
        )

      csv_string =
        token.contract_address_hash
        |> TokenTransfersExporter.export(from_period, to_period, [], nil, nil)
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      [header | rows] = String.split(csv_string, "\r\n", trim: true)

      assert header =~ "TxHash"
      assert header =~ "BlockNumber"
      assert header =~ "FromAddress"
      assert header =~ "ToAddress"
      assert header =~ "TokenContractAddress"
      assert header =~ "TokenDecimals"
      assert header =~ "TokenSymbol"
      assert header =~ "TokensTransferred"
      assert header =~ "TransactionFee"
      assert header =~ "Status"
      assert header =~ "ErrCode"

      assert length(rows) == 2

      assert Enum.any?(rows, fn row ->
               row =~ Address.checksum(transfer1.from_address_hash)
             end)

      assert Enum.any?(rows, fn row ->
               row =~ Address.checksum(transfer2.from_address_hash)
             end)
    end

    test "formats addresses as checksummed", %{from_period: from_period, to_period: to_period} do
      token = insert(:token, type: "ERC-20", decimals: 6, symbol: "USDC")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      transfer =
        insert(:token_transfer,
          transaction: transaction,
          token_contract_address: token.contract_address,
          token_type: "ERC-20",
          block_number: transaction.block_number,
          amount: Decimal.new(500)
        )

      csv_string =
        token.contract_address_hash
        |> TokenTransfersExporter.export(from_period, to_period, [], nil, nil)
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      [_header | rows] = String.split(csv_string, "\r\n", trim: true)

      assert length(rows) == 1
      row = hd(rows)
      assert row =~ Address.checksum(transfer.from_address_hash)
      assert row =~ Address.checksum(transfer.to_address_hash)
      assert row =~ Address.checksum(transfer.token_contract_address_hash)
    end

    test "does not include transfers from other tokens", %{from_period: from_period, to_period: to_period} do
      token = insert(:token, type: "ERC-20", decimals: 18, symbol: "AAA")
      other_token = insert(:token, type: "ERC-20", decimals: 18, symbol: "BBB")

      transaction1 =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction1,
        token_contract_address: token.contract_address,
        token_type: "ERC-20",
        block_number: transaction1.block_number,
        amount: Decimal.new(100)
      )

      transaction2 =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction2,
        token_contract_address: other_token.contract_address,
        token_type: "ERC-20",
        block_number: transaction2.block_number,
        amount: Decimal.new(200)
      )

      csv_string =
        token.contract_address_hash
        |> TokenTransfersExporter.export(from_period, to_period, [], nil, nil)
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      [_header | rows] = String.split(csv_string, "\r\n", trim: true)

      assert length(rows) == 1
    end

    test "respects pagination with many transfers", %{from_period: from_period, to_period: to_period} do
      token = insert(:token, type: "ERC-20", decimals: 18, symbol: "TKN")

      Enum.each(1..200, fn _i ->
        transaction =
          :transaction
          |> insert()
          |> with_block()

        insert(:token_transfer,
          transaction: transaction,
          token_contract_address: token.contract_address,
          token_type: "ERC-20",
          block_number: transaction.block_number,
          amount: Decimal.new(1)
        )
      end)

      csv_string =
        token.contract_address_hash
        |> TokenTransfersExporter.export(from_period, to_period, [], nil, nil)
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      [_header | rows] = String.split(csv_string, "\r\n", trim: true)

      assert length(rows) == 150
    end
  end
end
