# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Address.TokenTransfersTest do
  use Explorer.DataCase

  alias Explorer.Chain.Address
  alias Explorer.Chain.CsvExport.Address.TokenTransfers, as: AddressTokenTransfersCsvExporter

  describe "export/3" do
    test "exports token transfers to csv" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      token_transfer =
        insert(:token_transfer, transaction: transaction, from_address: address, block_number: transaction.block_number)
        |> Repo.preload([:token, :transaction])

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      [result] =
        address.hash
        |> AddressTokenTransfersCsvExporter.export(from_period, to_period, [], nil, nil)
        |> Enum.to_list()
        |> Enum.drop(1)
        |> Enum.map(fn [
                         [[], transaction_hash],
                         _,
                         [[], block_number],
                         _,
                         [[], timestamp],
                         _,
                         [[], from_address],
                         _,
                         [[], to_address],
                         _,
                         [[], token_contract_address],
                         _,
                         [[], type],
                         _,
                         [[], token_decimals],
                         _,
                         [[], token_symbol],
                         _,
                         [[], tokens_transferred],
                         _,
                         [[], ui_multiplier],
                         _,
                         [[], transaction_fee],
                         _,
                         [[], status],
                         _,
                         [[], err_code],
                         _
                       ] ->
          %{
            transaction_hash: transaction_hash,
            block_number: block_number,
            timestamp: timestamp,
            from_address: from_address,
            to_address: to_address,
            token_contract_address: token_contract_address,
            type: type,
            token_decimals: token_decimals,
            token_symbol: token_symbol,
            tokens_transferred: tokens_transferred,
            ui_multiplier: ui_multiplier,
            transaction_fee: transaction_fee,
            status: status,
            err_code: err_code
          }
        end)

      assert result.block_number == to_string(transaction.block_number)
      assert result.transaction_hash == to_string(transaction.hash)
      assert result.from_address == Address.checksum(token_transfer.from_address_hash)
      assert result.to_address == Address.checksum(token_transfer.to_address_hash)
      assert result.timestamp == to_string(transaction.block_timestamp)
      assert result.token_symbol == to_string(token_transfer.token.symbol)
      assert result.token_decimals == to_string(token_transfer.token.decimals)
      assert result.tokens_transferred == to_string(token_transfer.amount)
      assert result.status == to_string(token_transfer.transaction.status)
      assert result.err_code == to_string(token_transfer.transaction.error)
      assert result.type == "OUT"
      assert result.ui_multiplier == ""
    end

    test "exports the ERC-8056 multiplier of the moment of the transfer, leaving the amount raw" do
      address = insert(:address)

      token =
        insert(:token,
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
      transaction = :transaction |> insert(from_address: address) |> with_block(block)

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: block,
          block_number: block.number,
          from_address: address,
          token_contract_address: token.contract_address
        )

      [row] =
        address.hash
        |> AddressTokenTransfersCsvExporter.export("2026-04-01", "2026-07-01", [], nil, nil)
        |> Enum.to_list()
        |> Enum.drop(1)
        |> Enum.map(&(&1 |> IO.iodata_to_binary() |> String.trim() |> String.split(",")))

      # raw amount, plus the multiplier the holders saw back then rather than
      # the one in force now
      assert Enum.at(row, 9) == to_string(token_transfer.amount)
      assert Enum.at(row, 10) == "1000000000000000000"
    end

    test "fetches all token transfers" do
      address = insert(:address)

      1..200
      |> Enum.map(fn _ ->
        transaction =
          :transaction
          |> insert(from_address: address)
          |> with_block()

        insert(:token_transfer,
          transaction: transaction,
          from_address: address,
          block_number: transaction.block_number
        )
      end)
      |> Enum.count()

      1..200
      |> Enum.map(fn _ ->
        transaction =
          :transaction
          |> insert(to_address: address)
          |> with_block()

        insert(:token_transfer,
          transaction: transaction,
          to_address: address,
          block_number: transaction.block_number
        )
      end)
      |> Enum.count()

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      result =
        address.hash
        |> AddressTokenTransfersCsvExporter.export(from_period, to_period, [], nil, nil)
        |> Enum.to_list()
        |> Enum.drop(1)

      assert Enum.count(result) == 400
    end
  end
end
