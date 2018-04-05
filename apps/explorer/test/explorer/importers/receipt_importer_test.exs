defmodule Explorer.ReceiptImporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Log, Receipt}
  alias Explorer.ReceiptImporter

  describe "import/1" do
    test "saves a receipt to the database" do
      transaction =
        insert(
          :transaction,
          hash: "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291"
        )

      use_cassette "transaction_importer_import_1_receipt" do
        ReceiptImporter.import(
          "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291"
        )

        receipt = Receipt |> preload([:transaction]) |> Repo.one()
        assert receipt.transaction == transaction
      end
    end

    test "saves a receipt log" do
      insert(
        :transaction,
        hash: "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291"
      )

      use_cassette "transaction_importer_import_1_receipt" do
        ReceiptImporter.import(
          "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291"
        )

        receipt = Receipt |> preload([:transaction]) |> Repo.one()
        log = Log |> preload(receipt: :transaction) |> Repo.one()
        assert log.receipt == receipt
      end
    end

    test "saves a receipt log for an address" do
      insert(
        :transaction,
        hash: "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291"
      )

      address = insert(:address, hash: "0x353fe3ffbf77edef7f9c352c47965a38c07e837c")

      use_cassette "transaction_importer_import_1_receipt" do
        ReceiptImporter.import(
          "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291"
        )

        log = Log |> preload([:address]) |> Repo.one()
        assert log.address == address
      end
    end

    test "saves a receipt for a failed transaction" do
      insert(
        :transaction,
        hash: "0x2532864dc2e0d0bc2dfabf4685c0c03dbdbe9cf67ebc593fc82d41087ab71435"
      )

      use_cassette "transaction_importer_import_1_failed" do
        ReceiptImporter.import(
          "0x2532864dc2e0d0bc2dfabf4685c0c03dbdbe9cf67ebc593fc82d41087ab71435"
        )

        receipt = Repo.one(Receipt)
        assert receipt.status == 0
      end
    end

    test "saves a receipt for a transaction that ran out of gas" do
      insert(
        :transaction,
        hash: "0x702e518267b0a57e4cb44b9db100afe4d7115f2d2650466a8c376f3dbb77eb35"
      )

      use_cassette "transaction_importer_import_1_out_of_gas" do
        ReceiptImporter.import(
          "0x702e518267b0a57e4cb44b9db100afe4d7115f2d2650466a8c376f3dbb77eb35"
        )

        receipt = Repo.one(Receipt)
        assert receipt.status == 0
      end
    end

    test "does not import a receipt for a transaction that already has one" do
      transaction =
        insert(
          :transaction,
          hash: "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291"
        )

      insert(:receipt, transaction: transaction)

      use_cassette "transaction_importer_import_1_receipt" do
        ReceiptImporter.import(
          "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291"
        )

        assert Repo.all(Receipt) |> Enum.count() == 1
      end
    end

    test "does not import a receipt for a nonexistent transaction" do
      use_cassette "transaction_importer_import_1_receipt" do
        ReceiptImporter.import(
          "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291"
        )

        assert Repo.all(Receipt) |> Enum.count() == 0
      end
    end

    test "does not process a forever-pending receipt" do
      insert(
        :transaction,
        hash: "0xde791cfcde3900d4771e5fcf8c11dc305714118df7aa7e42f84576e64dbf6246"
      )

      use_cassette "transaction_importer_import_1_pending" do
        ReceiptImporter.import(
          "0xde791cfcde3900d4771e5fcf8c11dc305714118df7aa7e42f84576e64dbf6246"
        )

        assert Repo.all(Receipt) |> Enum.count() == 0
      end
    end
  end
end
