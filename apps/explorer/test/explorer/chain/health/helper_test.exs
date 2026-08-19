# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Health.HelperTest do
  use Explorer.DataCase
  alias Explorer.Chain.Health.Helper, as: HealthHelper
  alias Explorer.Chain.Cache.Blocks

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Blocks.child_id())

    :ok
  end

  describe "last_cache_block/0" do
    test "returns {block_number, block_timestamp}" do
      block = insert(:block, consensus: true)

      Blocks.update(block)

      assert {block.number, block.timestamp} == HealthHelper.last_cache_block()
    end

    test "return nil, if no blocks in the DB" do
      assert nil == HealthHelper.last_cache_block()
    end
  end

  describe "blocks_indexing_healthy?/1" do
    setup do
      Application.put_env(:explorer, Explorer.Chain.Health.Monitor, healthy_blocks_period: 300_000)
      :ok
    end

    defp unix_now, do: DateTime.to_unix(DateTime.utc_now())

    defp base_status(overrides \\ %{}) do
      now = unix_now()

      Map.merge(
        %{
          health_latest_block_timestamp_from_db: Decimal.new(now),
          health_latest_block_number_from_db: Decimal.new(100),
          health_latest_block_timestamp_from_cache: Decimal.new(now),
          health_latest_block_number_from_cache: Decimal.new(100),
          health_latest_block_number_from_node: Decimal.new(100),
          health_latest_batch_timestamp_from_db: nil,
          health_latest_batch_number_from_db: nil,
          health_latest_batch_average_time_from_db: nil
        },
        overrides
      )
    end

    test "returns true when nil" do
      assert true == HealthHelper.blocks_indexing_healthy?(nil)
    end

    test "returns error when db has no blocks" do
      status = base_status(%{health_latest_block_timestamp_from_db: nil})
      assert {false, _, _} = HealthHelper.blocks_indexing_healthy?(status)
    end

    test "returns true when db and cache are both current" do
      assert true == HealthHelper.blocks_indexing_healthy?(base_status())
    end

    test "returns true when cache timestamps are absent" do
      status = base_status(%{health_latest_block_timestamp_from_cache: nil})
      assert true == HealthHelper.blocks_indexing_healthy?(status)
    end

    test "returns error when cache lags behind db beyond threshold" do
      now = unix_now()
      stale = now - 600

      status =
        base_status(%{
          health_latest_block_timestamp_from_db: Decimal.new(now),
          health_latest_block_timestamp_from_cache: Decimal.new(stale)
        })

      assert {false, 5001, message} = HealthHelper.blocks_indexing_healthy?(status)
      assert message =~ "Cache block is lagging"
    end

    test "returns true when cache lag is within threshold" do
      now = unix_now()
      recent = now - 60

      status =
        base_status(%{
          health_latest_block_timestamp_from_db: Decimal.new(now),
          health_latest_block_timestamp_from_cache: Decimal.new(recent)
        })

      assert true == HealthHelper.blocks_indexing_healthy?(status)
    end
  end

  describe "deposits_indexing_healthy?/1" do
    setup do
      initial = Application.get_env(:explorer, Explorer.Chain.Health.Monitor)

      Application.put_env(
        :explorer,
        Explorer.Chain.Health.Monitor,
        Keyword.merge(initial || [], healthy_deposits_period: 300_000)
      )

      on_exit(fn -> Application.put_env(:explorer, Explorer.Chain.Health.Monitor, initial) end)

      :ok
    end

    defp deposit_unix_now, do: DateTime.to_unix(DateTime.utc_now())

    test "returns true when nil" do
      assert true == HealthHelper.deposits_indexing_healthy?(nil)
    end

    test "returns error when db has no deposits" do
      status = %{health_latest_deposit_timestamp_from_db: nil}
      assert {false, 5002, "There are no deposits in the DB."} = HealthHelper.deposits_indexing_healthy?(status)
    end

    test "returns true when latest deposit is within the healthy period" do
      status = %{health_latest_deposit_timestamp_from_db: Decimal.new(deposit_unix_now())}
      assert true == HealthHelper.deposits_indexing_healthy?(status)
    end

    test "returns error when latest deposit is stale" do
      stale = deposit_unix_now() - 600
      status = %{health_latest_deposit_timestamp_from_db: Decimal.new(stale)}

      assert {false, 5001, message} = HealthHelper.deposits_indexing_healthy?(status)
      assert message =~ "There are no new deposits in the DB"
    end
  end

  describe "withdrawals_indexing_healthy?/1" do
    setup do
      initial = Application.get_env(:explorer, Explorer.Chain.Health.Monitor)

      Application.put_env(
        :explorer,
        Explorer.Chain.Health.Monitor,
        Keyword.merge(initial || [], healthy_withdrawals_period: 300_000)
      )

      on_exit(fn -> Application.put_env(:explorer, Explorer.Chain.Health.Monitor, initial) end)

      :ok
    end

    defp withdrawal_unix_now, do: DateTime.to_unix(DateTime.utc_now())

    test "returns true when nil" do
      assert true == HealthHelper.withdrawals_indexing_healthy?(nil)
    end

    test "returns error when db has no withdrawals" do
      status = %{health_latest_withdrawal_timestamp_from_db: nil}
      assert {false, 5002, "There are no withdrawals in the DB."} = HealthHelper.withdrawals_indexing_healthy?(status)
    end

    test "returns true when latest withdrawal is within the healthy period" do
      status = %{health_latest_withdrawal_timestamp_from_db: Decimal.new(withdrawal_unix_now())}
      assert true == HealthHelper.withdrawals_indexing_healthy?(status)
    end

    test "returns error when latest withdrawal is stale" do
      stale = withdrawal_unix_now() - 600
      status = %{health_latest_withdrawal_timestamp_from_db: Decimal.new(stale)}

      assert {false, 5001, message} = HealthHelper.withdrawals_indexing_healthy?(status)
      assert message =~ "There are no new withdrawals in the DB"
    end
  end

  describe "last_db_block_status/0" do
    test "return no_blocks errors if db is empty" do
      assert {:error, :no_blocks} = HealthHelper.last_db_block_status()
    end

    test "returns {:ok, last_block_period} if block is in healthy period" do
      insert(:block, consensus: true)

      assert {:ok, _, _} = HealthHelper.last_db_block_status()
    end

    test "return {:stale, _, _} if block is not in healthy period" do
      insert(:block, consensus: true, timestamp: Timex.shift(DateTime.utc_now(), hours: -50))

      assert {:stale, _, _} = HealthHelper.last_db_block_status()
    end
  end
end
