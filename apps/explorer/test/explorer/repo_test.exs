defmodule Explorer.RepoTest do
  use Explorer.DataCase

  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias Ecto.Changeset
  alias Explorer.Chain.InternalTransaction

  @moduletag :capture_log

  describe "safe_insert_all/3" do
    test "inserting duplicate rows in one chunk is logged before re-raising exception" do
      transaction = insert(:transaction) |> with_block()

      params =
        params_for(
          :internal_transaction,
          from_address_hash: insert(:address).hash,
          to_address_hash: insert(:address).hash,
          transaction_hash: transaction.hash,
          index: 0,
          block_number: 35,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: 0
        )

      %Changeset{valid?: true, changes: changes} = InternalTransaction.changeset(%InternalTransaction{}, params)
      at = DateTime.utc_now()
      timestamped_changes = Map.merge(changes, %{inserted_at: at, updated_at: at})

      log =
        capture_log(fn ->
          assert_raise Postgrex.Error, fn ->
            Repo.safe_insert_all(
              InternalTransaction,
              [timestamped_changes, timestamped_changes],
              conflict_target: [:block_hash, :block_index],
              on_conflict: :replace_all
            )
          end
        end)

      assert log =~ "Chunk:\n"
      assert log =~ "index: 0"

      assert log =~ "Options:\n\n[conflict_target: [:block_hash, :block_index], on_conflict: :replace_all]\n\n"

      assert log =~
               "Exception:\n\n** (Postgrex.Error) ERROR 21000 (cardinality_violation) ON CONFLICT DO UPDATE command cannot affect row a second time\n"
    end
  end
end
