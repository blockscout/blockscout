defmodule Explorer.Workers.ImportTransactionTest do
  use Explorer.DataCase

  import Mock

  alias Explorer.InternalTransaction
  alias Explorer.Receipt
  alias Explorer.Repo
  alias Explorer.Transaction
  alias Explorer.Workers.ImportInternalTransaction
  alias Explorer.Workers.ImportTransaction

  describe "perform/1" do
    test "imports the requested transaction hash" do
      use_cassette "import_transaction_perform_1" do
        with_mock Exq, enqueue: fn _, _, _, _ -> :ok end do
          ImportTransaction.perform(
            "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
          )
        end

        transaction = Transaction |> Repo.one()

        assert transaction.hash ==
                 "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
      end
    end

    test "when there is already a transaction with the requested hash" do
      insert(
        :transaction,
        hash: "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
      )

      use_cassette "import_transaction_perform_1" do
        with_mock Exq, enqueue: fn _, _, _, _ -> :ok end do
          ImportTransaction.perform(
            "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
          )
        end

        transaction_count = Transaction |> Repo.all() |> Enum.count()
        assert transaction_count == 1
      end
    end

    test "imports the receipt in another queue" do
      transaction =
        insert(
          :transaction,
          hash: "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
        )

      use_cassette "import_transaction_perform_1" do
        with_mock Exq, enqueue: fn _, _, _, _ -> insert(:receipt, transaction: transaction) end do
          with_mock ImportInternalTransaction, perform_later: fn _ -> :ok end do
            ImportTransaction.perform(
              "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
            )

            receipt = Repo.one(Receipt)
            refute is_nil(receipt)
          end
        end
      end
    end

    test "imports the receipt in another queue when a map is supplied" do
      transaction =
        insert(
          :transaction,
          hash: "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
        )

      use_cassette "import_transaction_perform_1" do
        with_mock Exq, enqueue: fn _, _, _, _ -> insert(:receipt, transaction: transaction) end do
          with_mock ImportInternalTransaction, perform_later: fn _ -> :ok end do
            ImportTransaction.perform(%{
              "hash" => "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926",
              "to" => "0xc001",
              "from" => "0xbead5",
              "blockHash" => "0xcafe"
            })

            receipt = Repo.one(Receipt)
            refute is_nil(receipt)
          end
        end
      end
    end

    test "imports the internal transactions in another queue" do
      transaction =
        insert(
          :transaction,
          hash: "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
        )

      use_cassette "import_transaction_perform_1" do
        with_mock Exq, enqueue: fn _, _, _, _ -> :ok end do
          with_mock ImportInternalTransaction,
            perform_later: fn _ -> insert(:internal_transaction, transaction: transaction) end do
            ImportTransaction.perform(
              "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
            )

            internal_transaction = Repo.one(InternalTransaction)
            refute is_nil(internal_transaction)
          end
        end
      end
    end

    test "imports the internal transactions in another queue when a map is supplied" do
      transaction =
        insert(
          :transaction,
          hash: "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
        )

      use_cassette "import_transaction_perform_1" do
        with_mock Exq, enqueue: fn _, _, _, _ -> :ok end do
          with_mock ImportInternalTransaction,
            perform_later: fn _ -> insert(:internal_transaction, transaction: transaction) end do
            ImportTransaction.perform(%{
              "hash" => "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926",
              "to" => "0xc001",
              "from" => "0xbead5",
              "blockHash" => "0xcafe"
            })

            internal_transaction = Repo.one(InternalTransaction)
            refute is_nil(internal_transaction)
          end
        end
      end
    end
  end

  describe "perform_later/1" do
    test "imports the transaction in another queue" do
      use_cassette "import_transaction_perform_1" do
        with_mock Exq,
          enqueue: fn _, _, _, _ ->
            insert(
              :transaction,
              hash: "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
            )
          end do
          ImportTransaction.perform_later(
            "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
          )

          transaction = Repo.one(Transaction)

          assert transaction.hash ==
                   "0xf9a0959d5ccde33ec5221ddba1c6d7eaf9580a8d3512c7a1a60301362a98f926"
        end
      end
    end
  end
end
