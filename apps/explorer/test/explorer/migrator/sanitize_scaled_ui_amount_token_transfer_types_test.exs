# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.SanitizeScaledUIAmountTokenTransferTypesTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.TokenTransfer

  alias Explorer.Migrator.{
    BackfillScaledUIAmountTokens,
    MigrationStatus,
    SanitizeScaledUIAmountTokenTransferTypes,
    TokenTransferTokenType
  }

  alias Explorer.Repo

  setup do
    Repo.delete_all(
      from(status in MigrationStatus,
        where: status.migration_name == ^SanitizeScaledUIAmountTokenTransferTypes.migration_name()
      )
    )

    :ok
  end

  defp complete_dependencies do
    MigrationStatus.set_status(BackfillScaledUIAmountTokens.migration_name(), "completed")
    MigrationStatus.set_status(TokenTransferTokenType.migration_name(), "completed")
  end

  defp run_migration do
    {:ok, pid} = SanitizeScaledUIAmountTokenTransferTypes.start_link([])
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000
  end

  defp reload_transfer(token_transfer) do
    Repo.get_by(TokenTransfer,
      transaction_hash: token_transfer.transaction_hash,
      block_hash: token_transfer.block_hash,
      log_index: token_transfer.log_index
    )
  end

  defp insert_transfer(token, token_type) do
    block = insert(:block)
    transaction = :transaction |> insert() |> with_block(block)

    insert(:token_transfer,
      transaction: transaction,
      block: block,
      block_number: block.number,
      token_contract_address: token.contract_address,
      token_type: token_type
    )
  end

  describe "Sanitize ERC-8056 token transfer types" do
    test "corrects the type of transfers indexed before the token was recognised" do
      complete_dependencies()

      token = insert(:token, type: "ERC-8056")
      # indexed while the token still looked like a plain ERC-20
      token_transfer = insert_transfer(token, "ERC-20")

      run_migration()

      assert %{token_type: "ERC-8056"} = reload_transfer(token_transfer)

      assert MigrationStatus.get_status(SanitizeScaledUIAmountTokenTransferTypes.migration_name()) == "completed"
    end

    test "leaves transfers of other tokens alone" do
      complete_dependencies()

      token = insert(:token)
      token_transfer = insert_transfer(token, "ERC-20")

      run_migration()

      assert %{token_type: "ERC-20"} = reload_transfer(token_transfer)
    end

    test "waits for the migrations it depends on" do
      MigrationStatus.set_status(BackfillScaledUIAmountTokens.migration_name(), "completed")
      MigrationStatus.set_status(TokenTransferTokenType.migration_name(), "started")

      token = insert(:token, type: "ERC-8056")
      token_transfer = insert_transfer(token, "ERC-20")

      {:ok, pid} = SanitizeScaledUIAmountTokenTransferTypes.start_link([])
      Process.sleep(200)

      assert %{token_type: "ERC-20"} = reload_transfer(token_transfer)
      refute MigrationStatus.get_status(SanitizeScaledUIAmountTokenTransferTypes.migration_name()) == "completed"

      GenServer.stop(pid)
    end
  end
end
