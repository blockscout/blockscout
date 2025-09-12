defmodule Indexer.Fetcher.TokenInstance.SanitizeERC721Test do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Chain.Token.Instance
  alias Explorer.Application.Constants
  alias Explorer.Migrator.MigrationStatus

  describe "sanitizer test" do
    setup do
      initial_env = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.SanitizeERC721)

      on_exit(fn ->
        Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.SanitizeERC721, initial_env)
      end)

      {:ok, initial_env: initial_env}
    end

    test "imports token instances" do
      for x <- 0..3 do
        erc_721_token = insert(:token, type: "ERC-721")

        transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

        address = insert(:address)

        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          from_address: address,
          token_contract_address: erc_721_token.contract_address,
          token_ids: [x]
        )
      end

      assert [] = Repo.all(Instance)

      start_supervised!({Indexer.Fetcher.TokenInstance.SanitizeERC721, []})
      start_supervised!({Indexer.Fetcher.TokenInstance.Sanitize.Supervisor, [[flush_interval: 1]]})

      :timer.sleep(500)

      instances = Repo.all(Instance)

      assert Enum.count(instances) == 4
      assert Enum.all?(instances, fn instance -> !is_nil(instance.error) and is_nil(instance.metadata) end)
      assert MigrationStatus.get_status("backfill_erc721") == "completed"
    end

    test "imports token instances with low tokens queue size", %{initial_env: initial_env} do
      tokens =
        for x <- 0..5 do
          erc_721_token = insert(:token, type: "ERC-721")

          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          address = insert(:address)

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            from_address: address,
            token_contract_address: erc_721_token.contract_address,
            token_ids: [x]
          )

          erc_721_token
        end

      assert [] = Repo.all(Instance)

      Application.put_env(
        :indexer,
        Indexer.Fetcher.TokenInstance.SanitizeERC721,
        Keyword.put(initial_env, :tokens_queue_size, 1)
      )

      start_supervised!({Indexer.Fetcher.TokenInstance.SanitizeERC721, []})
      start_supervised!({Indexer.Fetcher.TokenInstance.Sanitize.Supervisor, [[flush_interval: 1]]})

      :timer.sleep(500)

      instances = Repo.all(Instance)

      assert Enum.count(instances) == 6
      assert Enum.all?(instances, fn instance -> !is_nil(instance.error) and is_nil(instance.metadata) end)

      assert MigrationStatus.get_status("backfill_erc721") == "completed"
      assert List.last(tokens).contract_address_hash == Constants.get_last_processed_token_address_hash()
    end

    test "don't start if completed" do
      MigrationStatus.set_status("backfill_erc721", "completed")

      for x <- 0..5 do
        erc_721_token = insert(:token, type: "ERC-721")

        transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

        address = insert(:address)

        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          from_address: address,
          token_contract_address: erc_721_token.contract_address,
          token_ids: [x]
        )
      end

      assert [] = Repo.all(Instance)

      start_supervised!({Indexer.Fetcher.TokenInstance.SanitizeERC721, []})
      start_supervised!({Indexer.Fetcher.TokenInstance.Sanitize.Supervisor, [[flush_interval: 1]]})

      :timer.sleep(500)

      instances = Repo.all(Instance)

      assert Enum.count(instances) == 0

      assert MigrationStatus.get_status("backfill_erc721") == "completed"
    end

    test "takes into account the last processed token address hash" do
      tokens =
        for x <- 0..5 do
          erc_721_token = insert(:token, type: "ERC-721")

          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          address = insert(:address)

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            from_address: address,
            token_contract_address: erc_721_token.contract_address,
            token_ids: [x]
          )

          erc_721_token
        end

      assert [] = Repo.all(Instance)

      pid_sanitize_erc721 = start_supervised!({Indexer.Fetcher.TokenInstance.SanitizeERC721, []})
      start_supervised!({Indexer.Fetcher.TokenInstance.Sanitize.Supervisor, [[flush_interval: 1]]})

      :timer.sleep(500)

      instances = Repo.all(Instance)

      assert Enum.count(instances) == 6
      last_token = List.last(tokens)
      assert MigrationStatus.get_status("backfill_erc721") == "completed"
      assert last_token.contract_address_hash == Constants.get_last_processed_token_address_hash()
      refute Process.alive?(pid_sanitize_erc721)

      first_token = List.first(tokens)

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      address = insert(:address)

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        from_address: address,
        token_contract_address: first_token.contract_address,
        token_ids: [6]
      )

      MigrationStatus.set_status("backfill_erc721", "started")

      {:ok, supervisor} = ExUnit.fetch_test_supervisor()

      {:ok, _pid_sanitize_erc721} =
        Supervisor.restart_child(supervisor, Indexer.Fetcher.TokenInstance.SanitizeERC721)

      :timer.sleep(500)

      assert MigrationStatus.get_status("backfill_erc721") == "completed"
      assert last_token.contract_address_hash == Constants.get_last_processed_token_address_hash()

      instances = Repo.all(Instance)

      assert Enum.count(instances) == 6
    end
  end
end
