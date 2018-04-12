defmodule Explorer.Workers.ImportReceiptTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Receipt
  alias Explorer.Workers.ImportReceipt

  describe "perform/1" do
    test "does not import a receipt when no transaction with the hash exists" do
      use_cassette "import_receipt_perform_1" do
        ImportReceipt.perform(
          "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
        )

        assert Repo.one(Receipt) == nil
      end
    end

    test "imports a receipt when a transaction with the hash exists" do
      insert(
        :transaction,
        hash: "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
      )

      use_cassette "import_receipt_perform_1" do
        ImportReceipt.perform(
          "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
        )

        receipt_count = Receipt |> Repo.all() |> Enum.count()
        assert receipt_count == 1
      end
    end
  end
end
