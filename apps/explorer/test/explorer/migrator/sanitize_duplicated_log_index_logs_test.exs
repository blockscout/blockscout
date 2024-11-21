defmodule Explorer.Migrator.SanitizeDuplicatedLogIndexLogsTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.Log
  alias Explorer.Chain.TokenTransfer
  alias Explorer.Chain.Token.Instance
  alias Explorer.Migrator.{SanitizeDuplicatedLogIndexLogs, MigrationStatus}

  if Application.compile_env(:explorer, :chain_type) in [:polygon_zkevm, :rsk, :filecoin] do
    describe "Sanitize duplicated log index logs" do
      test "correctly identifies and updates duplicated log index logs" do
        block = insert(:block)

        tx1 = :transaction |> insert() |> with_block(block, index: 0)
        tx2 = :transaction |> insert() |> with_block(block, index: 1)

        _log1 = insert(:log, transaction: tx1, index: 3, data: "0x01", block: block, block_number: block.number)
        _log2 = insert(:log, transaction: tx1, index: 0, data: "0x02", block: block, block_number: block.number)
        _log3 = insert(:log, transaction: tx2, index: 3, data: "0x03", block: block, block_number: block.number)

        log4 = insert(:log)

        assert MigrationStatus.get_status("sanitize_duplicated_log_index_logs") == nil

        SanitizeDuplicatedLogIndexLogs.start_link([])
        :timer.sleep(500)

        assert MigrationStatus.get_status("sanitize_duplicated_log_index_logs") == "completed"
        assert BackgroundMigrations.get_sanitize_duplicated_log_index_logs_finished() == true

        updated_logs =
          Repo.all(Log |> where([log], log.block_number == ^block.number) |> order_by([log], asc: log.index))

        Process.sleep(300)

        assert match?(
                 [
                   %{index: 0, data: %Explorer.Chain.Data{bytes: <<2>>}},
                   %{index: 1, data: %Explorer.Chain.Data{bytes: <<1>>}},
                   %{index: 2, data: %Explorer.Chain.Data{bytes: <<3>>}}
                 ],
                 updated_logs
               )

        assert %Log{log4 | address: nil, block: nil, transaction: nil} == %Log{
                 Repo.one(Log |> where([log], log.block_number != ^block.number))
                 | address: nil,
                   block: nil,
                   transaction: nil
               }
      end

      test "correctly identifies and updates duplicated log index logs & updates corresponding token transfers and token instances" do
        block = insert(:block)
        token_address = insert(:contract_address)
        insert(:token, contract_address: token_address, type: "ERC-721")

        instance = insert(:token_instance, token_contract_address_hash: token_address.hash)

        tx1 = :transaction |> insert() |> with_block(block, index: 0)
        tx2 = :transaction |> insert() |> with_block(block, index: 1)

        log1 = insert(:log, transaction: tx1, index: 3, data: "0x01", block: block, block_number: block.number)
        log2 = insert(:log, transaction: tx1, index: 0, data: "0x02", block: block, block_number: block.number)
        log3 = insert(:log, transaction: tx2, index: 3, data: "0x03", block: block, block_number: block.number)

        log4 = insert(:log)

        _tt1 =
          insert(:token_transfer,
            token_type: "ERC-721",
            block: block,
            block_number: block.number,
            log_index: log1.index,
            token_ids: [instance.token_id],
            token_contract_address: token_address,
            token_contract_address_hash: token_address.hash,
            transaction: tx1,
            transaction_hash: tx1.hash,
            block_hash: block.hash
          )

        _tt2 =
          insert(:token_transfer,
            block: block,
            block_number: block.number,
            log_index: log2.index,
            transaction: tx1,
            transaction_hash: tx1.hash
          )

        _tt3 =
          insert(:token_transfer,
            block: block,
            block_number: block.number,
            log_index: log3.index,
            transaction: tx2,
            transaction_hash: tx2.hash
          )

        Instance.changeset(instance, %{owner_updated_at_block: block.number, owner_updated_at_log_index: log1.index})
        |> Repo.update!()

        assert MigrationStatus.get_status("sanitize_duplicated_log_index_logs") == nil

        SanitizeDuplicatedLogIndexLogs.start_link([])
        :timer.sleep(500)

        assert MigrationStatus.get_status("sanitize_duplicated_log_index_logs") == "completed"
        assert BackgroundMigrations.get_sanitize_duplicated_log_index_logs_finished() == true

        Process.sleep(300)

        updated_logs =
          Repo.all(Log |> where([log], log.block_number == ^block.number) |> order_by([log], asc: log.index))

        assert match?(
                 [
                   %{index: 0, data: %Explorer.Chain.Data{bytes: <<2>>}},
                   %{index: 1, data: %Explorer.Chain.Data{bytes: <<1>>}},
                   %{index: 2, data: %Explorer.Chain.Data{bytes: <<3>>}}
                 ],
                 updated_logs
               )

        block_number = block.number
        assert [%{owner_updated_at_block: ^block_number, owner_updated_at_log_index: 1}] = Repo.all(Instance)

        assert [%{log_index: 1, block_number: ^block_number}] =
                 Repo.all(TokenTransfer |> where([tt], tt.token_type == "ERC-721"))

        assert %Log{log4 | address: nil, block: nil, transaction: nil} == %Log{
                 Repo.one(Log |> where([log], log.block_number != ^block.number))
                 | address: nil,
                   block: nil,
                   transaction: nil
               }
      end

      test "correctly handles cases where there are no duplicated log index logs" do
        assert MigrationStatus.get_status("sanitize_duplicated_log_index_logs") == nil

        SanitizeDuplicatedLogIndexLogs.start_link([])
        :timer.sleep(100)

        assert MigrationStatus.get_status("sanitize_duplicated_log_index_logs") == "completed"
        assert BackgroundMigrations.get_sanitize_duplicated_log_index_logs_finished() == true
      end
    end
  end
end
