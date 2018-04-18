defmodule Explorer.Workers.ImportInternalTransactionTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Chain.InternalTransaction
  alias Explorer.Workers.ImportInternalTransaction

  describe "perform/1" do
    test "does not import the internal transactions when no transaction with the hash exists" do
      use_cassette "import_internal_transaction_perform_1" do
        assert_raise Ecto.NoResultsError, fn ->
          ImportInternalTransaction.perform("0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926")
        end
      end
    end

    test "imports a receipt when an internal transaction with the hash exists" do
      insert(
        :transaction,
        hash: "0x051e031f05b3b3a5ff73e1189c36e3e2a41fd1c2d9772b2c75349e22ed4d3f68"
      )

      use_cassette "import_internal_transaction_perform_1" do
        ImportInternalTransaction.perform("0x051e031f05b3b3a5ff73e1189c36e3e2a41fd1c2d9772b2c75349e22ed4d3f68")

        internal_transaction_count = InternalTransaction |> Repo.all() |> Enum.count()
        assert internal_transaction_count == 2
      end
    end
  end
end
