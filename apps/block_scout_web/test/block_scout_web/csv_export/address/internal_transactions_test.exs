# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.CsvExport.Address.InternalTransactionsTest do
  use Explorer.DataCase

  import Mox

  alias BlockScoutWeb.CsvExport.Address.InternalTransactions, as: AddressInternalTransactionsCsvExporter
  alias Explorer.Chain.{Address, InternalTransaction, Wei}
  alias Explorer.Utility.AddressIdToAddressHash

  describe "export/3" do
    test "exports address internal transactions to csv" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      internal_transaction =
        insert(:internal_transaction,
          index: 1,
          transaction: transaction,
          from_address: address,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      res =
        address.hash
        |> AddressInternalTransactionsCsvExporter.export(from_period, to_period, [], nil, nil)
        |> Enum.to_list()
        |> Enum.drop(1)

      [result] =
        res
        |> Enum.map(fn [
                         [[], transaction_hash],
                         _,
                         [[], index],
                         _,
                         [[], block_number],
                         _,
                         [[], transaction_index],
                         _,
                         [[], timestamp],
                         _,
                         [[], from_address_hash],
                         _,
                         [[], to_address_hash],
                         _,
                         [[], created_contract_address_hash],
                         _,
                         [[], type],
                         _,
                         [[], call_type],
                         _,
                         [[], gas],
                         _,
                         [[], gas_used],
                         _,
                         [[], value],
                         _,
                         [[], input],
                         _,
                         [[], output],
                         _,
                         [[], error],
                         _,
                         [[], fee],
                         _
                       ] ->
          %{
            transaction_hash: transaction_hash,
            index: index,
            block_number: block_number,
            transaction_index: transaction_index,
            timestamp: timestamp,
            from_address_hash: from_address_hash,
            to_address_hash: to_address_hash,
            created_contract_address_hash: created_contract_address_hash,
            type: type,
            call_type: call_type,
            gas: gas,
            gas_used: gas_used,
            value: value,
            input: input,
            output: output,
            error: error,
            fee: fee
          }
        end)

      assert result.transaction_hash == to_string(internal_transaction.transaction.hash)
      assert result.index == to_string(internal_transaction.index)
      assert result.block_number == to_string(internal_transaction.block_number)
      assert result.transaction_index == to_string(internal_transaction.transaction_index)
      assert result.timestamp

      assert result.from_address_hash ==
               Address.checksum(AddressIdToAddressHash.id_to_hash(internal_transaction.from_address_id))

      assert result.to_address_hash ==
               Address.checksum(AddressIdToAddressHash.id_to_hash(internal_transaction.to_address_id))

      assert result.created_contract_address_hash ==
               to_string(AddressIdToAddressHash.id_to_hash(internal_transaction.created_contract_address_hash))

      assert result.type == to_string(internal_transaction.type)
      assert result.call_type == to_string(internal_transaction.call_type)
      assert result.gas == to_string(internal_transaction.gas)
      assert result.gas_used == to_string(internal_transaction.gas_used)
      assert result.value == internal_transaction.value |> Wei.to(:wei) |> to_string()
      assert result.input == to_string(internal_transaction.input)
      assert result.output == to_string(internal_transaction.output)
      assert result.error == to_string(internal_transaction.error)

      assert result.fee ==
               to_string(
                 internal_transaction.transaction.gas_price
                 |> Wei.mult(internal_transaction.gas_used)
                 |> Wei.to(:wei)
               )
    end

    test "fetches all internal transactions" do
      address = insert(:address)

      1..200
      |> Enum.map(fn index ->
        transaction =
          :transaction
          |> insert()
          |> with_block()

        insert(:internal_transaction,
          index: index,
          transaction: transaction,
          from_address: address,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )
      end)

      1..200
      |> Enum.map(fn index ->
        transaction =
          :transaction
          |> insert()
          |> with_block()

        insert(:internal_transaction,
          index: index,
          transaction: transaction,
          to_address: address,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )
      end)

      1..200
      |> Enum.map(fn index ->
        transaction =
          :transaction
          |> insert()
          |> with_block()

        insert(:internal_transaction_create,
          index: index,
          transaction: transaction,
          created_contract_address: address,
          to_address: nil,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )
      end)

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      result =
        address.hash
        |> AddressInternalTransactionsCsvExporter.export(from_period, to_period, [], nil, nil)
        |> Enum.to_list()
        |> Enum.drop(1)

      assert Enum.count(result) == 600
    end

    test "excludes zero-value call internal transactions when include_zero_value: false" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      zero_value_call =
        insert(:internal_transaction,
          index: 1,
          transaction: transaction,
          to_address: address,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          type: :call,
          value: Decimal.new(0)
        )

      non_zero_call =
        insert(:internal_transaction,
          index: 2,
          transaction: transaction,
          to_address: address,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          type: :call,
          value: Decimal.new(1)
        )

      zero_value_create =
        insert(:internal_transaction_create,
          index: 3,
          transaction: transaction,
          created_contract_address: address,
          to_address: nil,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          value: Decimal.new(0)
        )

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      exported_indexes = fn options ->
        address.hash
        |> AddressInternalTransactionsCsvExporter.export(from_period, to_period, options, nil, nil)
        |> Enum.to_list()
        |> Enum.drop(1)
        |> Enum.map(fn [_, _, [[], index] | _] -> String.to_integer(index) end)
        |> Enum.sort()
      end

      assert exported_indexes.(include_zero_value: false) == [non_zero_call.index, zero_value_create.index]

      assert exported_indexes.([]) ==
               Enum.sort([zero_value_call.index, non_zero_call.index, zero_value_create.index])

      assert exported_indexes.(include_zero_value: true) == exported_indexes.([])
    end

    test "don't fall on is_nil(gas_used)" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      transaction_error = insert(:transaction_error, message: "reverted")

      internal_transaction =
        insert(:internal_transaction,
          index: 1,
          transaction: transaction,
          from_address: address,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          error: "reverted",
          error_id: transaction_error.id,
          gas_used: nil,
          output: nil
        )
        |> InternalTransaction.preload_addresses()

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      res =
        address.hash
        |> AddressInternalTransactionsCsvExporter.export(from_period, to_period, [], nil, nil)
        |> Enum.to_list()
        |> Enum.drop(1)

      [result] =
        res
        |> Enum.map(fn [
                         [[], transaction_hash],
                         _,
                         [[], index],
                         _,
                         [[], block_number],
                         _,
                         [[], transaction_index],
                         _,
                         [[], timestamp],
                         _,
                         [[], from_address_hash],
                         _,
                         [[], to_address_hash],
                         _,
                         [[], created_contract_address_hash],
                         _,
                         [[], type],
                         _,
                         [[], call_type],
                         _,
                         [[], gas],
                         _,
                         [[], gas_used],
                         _,
                         [[], value],
                         _,
                         [[], input],
                         _,
                         [[], output],
                         _,
                         [[], error],
                         _,
                         [[], fee],
                         _
                       ] ->
          %{
            transaction_hash: transaction_hash,
            index: index,
            block_number: block_number,
            transaction_index: transaction_index,
            timestamp: timestamp,
            from_address_hash: from_address_hash,
            to_address_hash: to_address_hash,
            created_contract_address_hash: created_contract_address_hash,
            type: type,
            call_type: call_type,
            gas: gas,
            gas_used: gas_used,
            value: value,
            input: input,
            output: output,
            error: error,
            fee: fee
          }
        end)

      assert result.transaction_hash == to_string(internal_transaction.transaction.hash)
      assert result.index == to_string(internal_transaction.index)
      assert result.block_number == to_string(internal_transaction.block_number)
      assert result.transaction_index == to_string(internal_transaction.transaction_index)
      assert result.timestamp
      assert result.from_address_hash == Address.checksum(internal_transaction.from_address_hash)
      assert result.to_address_hash == Address.checksum(internal_transaction.to_address_hash)
      assert result.created_contract_address_hash == to_string(internal_transaction.created_contract_address_hash)
      assert result.type == to_string(internal_transaction.type)
      assert result.call_type == to_string(internal_transaction.call_type)
      assert result.gas == to_string(internal_transaction.gas)
      assert result.gas_used == ""
      assert result.value == internal_transaction.value |> Wei.to(:wei) |> to_string()
      assert result.input == to_string(internal_transaction.input)
      assert result.output == to_string(internal_transaction.output)
      assert result.error == to_string(internal_transaction.error)

      assert result.fee == ""
    end
  end

  # `EthereumJSONRPC.RSK` and `EthereumJSONRPC.Filecoin` variants trace blocks with `trace_block`
  if Application.compile_env(:explorer, :chain_type) not in [:rsk, :filecoin] do
    describe "export/6 with internal transactions fetched from the node" do
      setup [:set_mox_global, :verify_on_exit!]

      setup do
        put_env(:explorer, InternalTransaction, storage_disabled?: true)
        put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, tracer: "call_tracer", block_traceable?: true)

        address = insert(:address)
        %{address_id: address_id} = insert(:address_id_to_address_hash, address: address)
        {:ok, now} = DateTime.now("Etc/UTC")

        %{
          address: address,
          address_id: address_id,
          now: now,
          from_period: now |> DateTime.add(-1, :minute) |> DateTime.to_iso8601(),
          to_period: DateTime.to_iso8601(now)
        }
      end

      test "goes on with the block where the node scan stopped", %{address: address} = context do
        # the node scan of a page of 2 internal transactions takes a block per round after the first one
        initial_limit = Application.get_env(:explorer, :csv_export_limit)
        Application.put_env(:explorer, :csv_export_limit, 2)
        on_exit(fn -> Application.put_env(:explorer, :csv_export_limit, initial_limit) end)

        insert_blocks_with_placeholders(1..7, context)

        # blocks 7 and 1 transfer value to the address, and the blocks between them have zero-value calls to it only
        expect(EthereumJSONRPC.Mox, :json_rpc, 6, fn requests, _ ->
          {:ok,
           Enum.map(requests, fn %{id: id, params: [block_quantity, _]} ->
             block_number = EthereumJSONRPC.quantity_to_integer(block_quantity)
             value = if block_number in [7, 1], do: "0x1", else: "0x0"
             %{id: id, result: block_traces_with_call_to(address, block_number, value)}
           end)}
        end)

        # the first scan stops before block 1 when its rounds are over
        assert exported_block_numbers(address, context, include_zero_value: false) == ["7", "1"]
      end

      test "fails when the node fails to trace a block", %{address: address} = context do
        put_env(:indexer, Indexer.Fetcher.OnDemand.InternalTransaction, blocks_batch_size: 1)

        insert_blocks_with_placeholders(1..3, context)

        # block 2 fails to be traced in the first scan, and again in the scan going on with it
        expect(EthereumJSONRPC.Mox, :json_rpc, 5, fn [%{id: id, params: [block_quantity, _]}], _ ->
          case EthereumJSONRPC.quantity_to_integer(block_quantity) do
            2 -> {:ok, [%{id: id, error: %{code: -32_000, message: "tracing failed"}}]}
            block_number -> {:ok, [%{id: id, result: block_traces_with_call_to(address, block_number, "0x1")}]}
          end
        end)

        assert_raise RuntimeError, ~r/block 2/, fn -> exported_block_numbers(address, context, []) end
      end
    end

    defp insert_blocks_with_placeholders(block_numbers, %{address_id: address_id, now: now}) do
      for block_number <- block_numbers do
        insert(:block, number: block_number, timestamp: DateTime.add(now, block_number - 10, :second))

        insert(:deleted_internal_transactions_address_placeholder,
          address_id: address_id,
          block_number: block_number,
          count_tos: 1,
          count_froms: 0
        )
      end
    end

    defp exported_block_numbers(address, %{from_period: from_period, to_period: to_period}, options) do
      address.hash
      |> AddressInternalTransactionsCsvExporter.export(from_period, to_period, options, nil, nil)
      |> Enum.drop(1)
      |> Enum.map(&(&1 |> IO.iodata_to_binary() |> String.split(",") |> Enum.at(2)))
    end

    # `debug_traceBlockByNumber` result with a transaction that transfers `value` to the address in a nested call
    defp block_traces_with_call_to(address, block_number, value) do
      [
        %{
          "result" => %{
            "calls" => [
              %{
                "from" => "0x4200000000000000000000000000000000000015",
                "gas" => "0xe9a3c",
                "gasUsed" => "0x4a28",
                "input" => "0x",
                "output" => "0x",
                "to" => to_string(address.hash),
                "type" => "CALL",
                "value" => value
              }
            ],
            "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
            "gas" => "0xf4240",
            "gasUsed" => "0xb6f9",
            "input" => "0x",
            "output" => "0x",
            "to" => "0x4200000000000000000000000000000000000015",
            "type" => "CALL",
            "value" => "0x0"
          },
          "txHash" => "0x" <> String.pad_leading("#{block_number}", 64, "0")
        }
      ]
    end

    # Merges `config` into the application config for the test
    defp put_env(app, key, config) do
      initial_config = Application.get_env(app, key)
      Application.put_env(app, key, Keyword.merge(initial_config || [], config))

      on_exit(fn ->
        if is_nil(initial_config) do
          Application.delete_env(app, key)
        else
          Application.put_env(app, key, initial_config)
        end
      end)
    end
  end
end
