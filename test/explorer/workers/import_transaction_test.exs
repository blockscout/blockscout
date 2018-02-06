defmodule Explorer.Workers.ImportTransactionTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Transaction
  alias Explorer.Workers.ImportTransaction

  describe "perform/1" do
    test "imports the requested transaction hash" do
      use_cassette "import_transaction_perform_1" do
        ImportTransaction.perform("0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926")
        transaction = Transaction |> Repo.one

        assert transaction.hash == "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
      end
    end

    test "when there is already a transaction with the requested hash" do
      use_cassette "import_transaction_perform_1_duplicate" do
        insert(:transaction, hash: "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
        ImportTransaction.perform("0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")
        transaction_count = Transaction |> Repo.all |> Enum.count

        assert transaction_count == 1
      end
    end
  end
end
