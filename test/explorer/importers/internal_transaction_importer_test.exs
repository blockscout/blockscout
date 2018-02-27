defmodule Explorer.InternalTransactionImporterTest do
  use Explorer.DataCase

  alias Explorer.InternalTransaction
  alias Explorer.InternalTransactionImporter

  describe "import/1" do
    test "imports and saves an internal transaction to the database" do
      use_cassette "internal_transaction_importer_import_1" do
        transaction =
          insert(
            :transaction,
            hash: "0x051e031f05b3b3a5ff73e1189c36e3e2a41fd1c2d9772b2c75349e22ed4d3f68"
          )

        InternalTransactionImporter.import(transaction.hash)
        internal_transactions = InternalTransaction |> Repo.all()
        assert length(internal_transactions) == 2
      end
    end

    test "imports internal transactions with ordered indexes" do
      use_cassette "internal_transaction_importer_import_1" do
        transaction =
          insert(
            :transaction,
            hash: "0x051e031f05b3b3a5ff73e1189c36e3e2a41fd1c2d9772b2c75349e22ed4d3f68"
          )

        InternalTransactionImporter.import(transaction.hash)

        last_internal_transaction =
          InternalTransaction |> order_by(desc: :index) |> limit(1) |> Repo.one()

        assert last_internal_transaction.index == 1
      end
    end

    test "imports an internal transaction that creates a contract" do
      use_cassette "internal_transaction_importer_import_1_with_contract_creation" do
        transaction =
          insert(
            :transaction,
            hash: "0x27d64b8e8564d2852c88767e967b88405c99341509cd3a3504fd67a65277116d"
          )

        InternalTransactionImporter.import(transaction.hash)

        last_internal_transaction =
          InternalTransaction |> order_by(desc: :index) |> limit(1) |> Repo.one()

        assert last_internal_transaction.call_type == "create"
      end
    end

    test "subsequent imports do not create duplicate internal transactions" do
      use_cassette "internal_transaction_importer_import_1" do
        transaction =
          insert(
            :transaction,
            hash: "0x051e031f05b3b3a5ff73e1189c36e3e2a41fd1c2d9772b2c75349e22ed4d3f68"
          )

        InternalTransactionImporter.import(transaction.hash)
        InternalTransactionImporter.import(transaction.hash)

        internal_transactions = InternalTransaction |> Repo.all()
        assert length(internal_transactions) == 2
      end
    end

    test "import fails if a transaction with the hash doesn't exist" do
      hash = "0x051e031f05b3b3a5ff73e1189c36e3e2a41fd1c2d9772b2c75349e22ed4d3f68"
      assert_raise Ecto.NoResultsError, fn -> InternalTransactionImporter.import(hash) end
    end
  end

  describe "extract_trace" do
    test "maps attributes to database record attributes when the trace is a call" do
      trace = %{
        "action" => %{
          "callType" => "call",
          "from" => "0xba9f067abbc4315ece8eb33e7a3d01030bb368ef",
          "gas" => "0x4821f",
          "input" => "0xd1f276d3",
          "to" => "0xe213402e637565bb9de0651827517e7554693f53",
          "value" => "0x0"
        },
        "result" => %{
          "gasUsed" => "0x4e4",
          "output" => "0x000000000000000000000000ba9f067abbc4315ece8eb33e7a3d01030bb368ef"
        },
        "subtraces" => 0,
        "traceAddress" => [2, 0],
        "type" => "call"
      }

      to_address = insert(:address, hash: "0xe213402e637565bb9de0651827517e7554693f53")
      from_address = insert(:address, hash: "0xba9f067abbc4315ece8eb33e7a3d01030bb368ef")

      assert(
        InternalTransactionImporter.extract_trace({trace, 2}) == %{
          index: 2,
          to_address_id: to_address.id,
          from_address_id: from_address.id,
          call_type: "call",
          trace_address: [2, 0],
          value: 0,
          gas: 295_455,
          gas_used: 1252,
          input: "0xd1f276d3",
          output: "0x000000000000000000000000ba9f067abbc4315ece8eb33e7a3d01030bb368ef"
        }
      )
    end
  end
end
