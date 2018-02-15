defmodule Explorer.ReceiptImporterTest do
  use Explorer.DataCase

  alias Explorer.Receipt
  alias Explorer.Log
  alias Explorer.ReceiptImporter

  describe "import/1" do
    test "imports and saves a transaction receipt to the database" do
      transaction = insert(:transaction, hash: "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
      use_cassette "transaction_importer_import_1_receipt" do
        ReceiptImporter.import("0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
        receipt = Receipt |> preload([:transaction]) |> Repo.one
        assert receipt.transaction == transaction
      end
    end

    test "imports and saves a transaction receipt log" do
      insert(:transaction, hash: "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
      use_cassette "transaction_importer_import_1_receipt" do
        ReceiptImporter.import("0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
        receipt = Receipt |> preload([:transaction]) |> Repo.one
        log = Log |> preload([receipt: :transaction]) |> Repo.one
        assert log.receipt == receipt
      end
    end

    test "imports and saves a transaction receipt log for an address" do
      insert(:transaction, hash: "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
      address = insert(:address, hash: "0x353fe3ffbf77edef7f9c352c47965a38c07e837c")
      use_cassette "transaction_importer_import_1_receipt" do
        ReceiptImporter.import("0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
        log = Log |> preload([:address]) |> Repo.one
        assert log.address == address
      end
    end

    test "does not import a receipt for a transaction that already has one" do
      transaction = insert(:transaction, hash: "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
      insert(:receipt, transaction: transaction)
      use_cassette "transaction_importer_import_1_receipt" do
        ReceiptImporter.import("0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
        assert Repo.all(Receipt) |> Enum.count() == 1
      end
    end

    test "does not import a receipt for a nonexistent transaction" do
      use_cassette "transaction_importer_import_1_receipt" do
        ReceiptImporter.import("0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
        assert Repo.all(Receipt) |> Enum.count() == 0
      end
    end

    test "does not process a forever-pending receipt" do
      insert(:transaction, hash: "0xde791cfcde3900d4771e5fcf8c11dc305714118df7aa7e42f84576e64dbf6246")
      use_cassette "transaction_importer_import_1_pending" do
        ReceiptImporter.import("0xde791cfcde3900d4771e5fcf8c11dc305714118df7aa7e42f84576e64dbf6246")
        assert Repo.all(Receipt) |> Enum.count() == 0
      end
    end
  end
end
