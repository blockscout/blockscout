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
      assert header =~ "UIMultiplier"
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

      # a token without ERC-8056 support has no multiplier to export
      assert Enum.all?(rows, &(&1 |> String.split(",") |> Enum.at(9) == ""))
    end

    test "exports the ERC-8056 multiplier of the moment of the transfer, leaving the amount raw" do
      token =
        insert(:token,
          type: "ERC-8056",
          ui_multiplier: Decimal.new("2000000000000000000"),
          new_ui_multiplier: Decimal.new("2000000000000000000"),
          ui_multiplier_effective_at: ~U[2026-06-01 00:00:00.000000Z]
        )

      insert(:token_ui_multiplier_change,
        token: token,
        block_number: 100,
        log_index: 0,
        old_multiplier: Decimal.new("1000000000000000000"),
        new_multiplier: Decimal.new("2000000000000000000"),
        effective_at: ~U[2026-06-01 00:00:00.000000Z]
      )

      block = insert(:block, number: 150, timestamp: ~U[2026-05-01 00:00:00.000000Z])
      transaction = :transaction |> insert() |> with_block(block)

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: block,
          block_number: block.number,
          token_contract_address: token.contract_address
        )

      [header | rows] =
        token.contract_address_hash
        |> TokenTransfersExporter.export("2026-04-01", "2026-07-01", [], nil, nil)
        |> Enum.to_list()
        |> IO.iodata_to_binary()
        |> String.split("\r\n", trim: true)

      assert header |> String.split(",") |> Enum.at(9) == "UIMultiplier"
      assert [row] = Enum.map(rows, &String.split(&1, ","))

      # raw amount, plus the multiplier the holders saw back then rather than
      # the one in force now
      assert Enum.at(row, 8) == to_string(token_transfer.amount)
      assert Enum.at(row, 9) == "1000000000000000000"
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

    test "respects export limit with many transfers", %{from_period: from_period, to_period: to_period} do
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
