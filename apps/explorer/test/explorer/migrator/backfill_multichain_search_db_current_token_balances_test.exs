# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.BackfillMultichainSearchDbCurrentTokenBalancesTest do
  use Explorer.DataCase, async: false

  alias Explorer.Migrator.{BackfillMultichainSearchDbCurrentTokenBalances, MigrationStatus}
  alias Explorer.TestHelper

  setup do
    original_migrator_env =
      Application.get_env(:explorer, BackfillMultichainSearchDbCurrentTokenBalances, [])

    original_multichain_env = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, [])
    original_tesla_adapter = Application.get_env(:tesla, :adapter)
    original_trace_block_ranges = Application.get_env(:indexer, :trace_block_ranges)

    Repo.delete_all(
      from(ms in MigrationStatus,
        where:
          ms.migration_name ==
            "backfill_multichain_search_db_current_token_balances"
      )
    )

    on_exit(fn ->
      Application.put_env(:explorer, BackfillMultichainSearchDbCurrentTokenBalances, original_migrator_env)
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, original_multichain_env)
      Application.put_env(:tesla, :adapter, original_tesla_adapter)
      Application.put_env(:indexer, :trace_block_ranges, original_trace_block_ranges)
    end)

    :ok
  end

  test "last_unprocessed_identifiers filters by configured last block and updates cursor state" do
    Application.put_env(:explorer, BackfillMultichainSearchDbCurrentTokenBalances,
      batch_size: 2,
      concurrency: 1,
      max_block_number: 100
    )

    balance_1 = insert(:address_current_token_balance, block_number: 90, token_type: "ERC-20")
    balance_2 = insert(:address_current_token_balance, block_number: 100, token_type: "ERC-20")
    insert(:address_current_token_balance, block_number: 101, token_type: "ERC-20")

    {ids, state} = BackfillMultichainSearchDbCurrentTokenBalances.last_unprocessed_identifiers(%{})

    assert ids == [balance_1.id, balance_2.id]
    assert state == %{"last_processed_id" => balance_2.id}

    assert {[], %{"last_processed_id" => balance_2.id}} ==
             BackfillMultichainSearchDbCurrentTokenBalances.last_unprocessed_identifiers(state)
  end

  test "last_unprocessed_identifiers filters by trace block ranges" do
    Application.put_env(:explorer, BackfillMultichainSearchDbCurrentTokenBalances,
      batch_size: 2,
      concurrency: 1,
      max_block_number: 100
    )

    Application.put_env(:indexer, :trace_block_ranges, "50..80")

    balance_in_range = insert(:address_current_token_balance, block_number: 60, token_type: "ERC-20")
    insert(:address_current_token_balance, block_number: 40, token_type: "ERC-20")
    insert(:address_current_token_balance, block_number: 90, token_type: "ERC-20")

    {ids, state} = BackfillMultichainSearchDbCurrentTokenBalances.last_unprocessed_identifiers(%{})

    assert ids == [balance_in_range.id]
    assert state == %{"last_processed_id" => balance_in_range.id}
  end

  test "update_batch exports only token balances payload" do
    Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch,
      service_url: "http://localhost:1234",
      api_key: "12345",
      addresses_chunk_size: 7000
    )

    Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)

    balance_1 = insert(:address_current_token_balance, block_number: 100, token_type: "ERC-20")
    balance_2 = insert(:address_current_token_balance, block_number: 110, token_type: "ERC-721", token_id: 1)

    TestHelper.get_chain_id_mock()

    Tesla.Test.expect_tesla_call(
      times: 1,
      returns: fn %{url: "http://localhost:1234/api/v1/import:batch", body: body}, _opts ->
        {:ok, payload} = Utils.JSON.decode(body)

        assert payload["addresses"] == []
        assert payload["block_ranges"] == []
        assert payload["hashes"] == []
        assert payload["address_coin_balances"] == []
        assert Enum.count(payload["address_token_balances"]) == 2

        assert Enum.any?(payload["address_token_balances"], fn token_balance ->
                 token_balance["address_hash"] == to_string(balance_1.address_hash) &&
                   token_balance["token_address_hash"] == to_string(balance_1.token_contract_address_hash) &&
                   token_balance["token_id"] == nil
               end)

        assert Enum.any?(payload["address_token_balances"], fn token_balance ->
                 token_balance["address_hash"] == to_string(balance_2.address_hash) &&
                   token_balance["token_address_hash"] == to_string(balance_2.token_contract_address_hash) &&
                   token_balance["token_id"] == "1"
               end)

        {:ok,
         %Tesla.Env{
           status: 200,
           body: Utils.JSON.encode!(%{"status" => "ok"})
         }}
      end
    )

    assert {:ok, {:chunks_processed, _}} =
             BackfillMultichainSearchDbCurrentTokenBalances.update_batch([balance_1.id, balance_2.id])
  end

  test "start_link completes migration and updates status" do
    Application.put_env(:explorer, BackfillMultichainSearchDbCurrentTokenBalances,
      batch_size: 1,
      concurrency: 1,
      max_block_number: 100
    )

    Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch,
      service_url: nil,
      api_key: nil,
      addresses_chunk_size: 7000
    )

    insert(:block)

    balance = insert(:address_current_token_balance, block_number: 100, token_type: "ERC-20")

    assert MigrationStatus.get_status("backfill_multichain_search_db_current_token_balances") == nil

    {:ok, _pid} = BackfillMultichainSearchDbCurrentTokenBalances.start_link([])
    Process.sleep(100)

    assert MigrationStatus.get_status("backfill_multichain_search_db_current_token_balances") == "completed"

    assert %MigrationStatus{meta: %{"last_processed_id" => last_processed_id}} =
             MigrationStatus.fetch("backfill_multichain_search_db_current_token_balances")

    assert last_processed_id == balance.id
  end
end
