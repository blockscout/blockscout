defmodule Explorer.TransactionReceiptImporterTest do
  use Explorer.DataCase

  alias Explorer.TransactionReceipt
  alias Explorer.TransactionReceiptImporter

  describe "import/1" do
    test "imports and saves a transaction receipt to the database" do
      transaction = insert(:transaction, hash: "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
      use_cassette "transaction_importer_import_1_receipt" do
        TransactionReceiptImporter.import("0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
        receipt = TransactionReceipt |> order_by(desc: :inserted_at) |> preload([:transaction]) |> Repo.one
        assert receipt.transaction == transaction
      end
    end

    test "does not import a receipt for a transaction that already has one" do
      transaction = insert(:transaction, hash: "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
      insert(:transaction_receipt, transaction: transaction)
      use_cassette "transaction_importer_import_1_receipt" do
        TransactionReceiptImporter.import("0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
        assert Repo.all(TransactionReceipt) |> Enum.count() == 1
      end
    end

    test "does not import a receipt for a nonexistent transaction" do
      use_cassette "transaction_importer_import_1_receipt" do
        TransactionReceiptImporter.import("0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
        assert Repo.all(TransactionReceipt) |> Enum.count() == 0
      end
    end
  end
end
