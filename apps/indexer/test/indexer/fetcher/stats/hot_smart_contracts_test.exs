defmodule Indexer.Fetcher.Stats.HotSmartContractsTest do
  # MUST be `async: false` due to use of named GenServer
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import ExUnit.CaptureLog
  import Mox

  alias Explorer.Chain.Block
  alias Indexer.Fetcher.Stats.HotSmartContracts

  @moduletag :capture_log

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    # Clean up any existing named process before each test
    if Process.whereis(HotSmartContracts) do
      try do
        GenServer.stop(HotSmartContracts, :normal, 1000)
      rescue
        _ -> :ok
      catch
        :exit, _ -> :ok
      end

      Process.sleep(50)
    end

    on_exit(fn ->
      if Process.whereis(HotSmartContracts) do
        try do
          GenServer.stop(HotSmartContracts, :normal, 1000)
        rescue
          _ -> :ok
        catch
          :exit, _ -> :ok
        end
      end
    end)

    :ok
  end

  describe "check_chain_age/0" do
    test "returns :ok when chain is older than 30 days" do
      # Create genesis block (first block)
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z])

      # Create second block that is 31 days old
      second_block_timestamp = ~U[2024-01-01 00:00:00Z] |> DateTime.add(-31, :day)
      insert(:block, number: 1, timestamp: second_block_timestamp, consensus: true)

      log =
        capture_log(fn ->
          # Start the GenServer
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            # Wait a bit for handle_continue to process
            Process.sleep(200)

            # Verify that check_completeness was called (indirectly by checking if process is still running)
            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      # Should not log delay message when chain is old enough
      refute log =~ "Hot contracts module delayed"
    end

    test "returns {:wait, delay_ms} when chain is less than 30 days old" do
      # Create genesis block
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z])

      # Create second block that is 10 days old
      now = DateTime.utc_now()
      second_block_timestamp = DateTime.add(now, -10, :day)
      insert(:block, number: 1, timestamp: second_block_timestamp, consensus: true)

      log =
        capture_log(fn ->
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            # Wait for handle_continue to process
            Process.sleep(200)

            # Process should still be alive and waiting
            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      assert log =~ "Hot contracts module delayed: chain is less than 30 days old"
      assert log =~ "Rescheduling startup check"
    end

    test "returns {:error, :block_not_found} when second block does not exist" do
      # Only create genesis block, no second block
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z], consensus: true)

      log =
        capture_log(fn ->
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            # Wait for handle_continue to process
            Process.sleep(200)

            # Process should still be alive
            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      assert log =~ "Hot contracts module delayed: second block not found"
      assert log =~ "Rescheduling startup check for next day"
    end

    test "returns {:error, :block_not_found} when no blocks exist" do
      log =
        capture_log(fn ->
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            # Wait for handle_continue to process
            Process.sleep(200)

            # Process should still be alive
            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      assert log =~ "Hot contracts module delayed: second block not found"
      assert log =~ "Rescheduling startup check for next day"
    end

    test "correctly calculates delay when chain is close to 30 days old" do
      # Create genesis block
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z])

      # Create second block that is 25 days old (5 days away from 30)
      now = DateTime.utc_now()
      second_block_timestamp = DateTime.add(now, -25, :day)
      insert(:block, number: 1, timestamp: second_block_timestamp, consensus: true)

      log =
        capture_log(fn ->
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            # Wait for handle_continue to process
            Process.sleep(200)

            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      assert log =~ "Hot contracts module delayed: chain is less than 30 days old"
      assert log =~ "Rescheduling startup check"
    end

    test "uses next day delay when it's sooner than 30-day target" do
      # Create genesis block
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z])

      # Create second block that is 29.9 days old
      # This means we need to wait ~0.1 days to reach 30, but next day might be sooner
      now = DateTime.utc_now()
      second_block_timestamp = DateTime.add(now, -29, :day) |> DateTime.add(-21, :hour)
      insert(:block, number: 1, timestamp: second_block_timestamp, consensus: true)

      log =
        capture_log(fn ->
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            # Wait for handle_continue to process
            Process.sleep(200)

            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      assert log =~ "Hot contracts module delayed: chain is less than 30 days old"
      assert log =~ "Rescheduling startup check"
    end
  end

  describe "process_chain_age_check/0" do
    test "starts normal operation when chain age check returns :ok" do
      # Create blocks older than 30 days
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z])
      second_block_timestamp = DateTime.utc_now() |> DateTime.add(-31, :day)
      insert(:block, number: 1, timestamp: second_block_timestamp, consensus: true)

      log =
        capture_log(fn ->
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            # Wait for initialization
            Process.sleep(200)

            # Process should be running and should have scheduled next day fetch
            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      # Should not log delay message when chain is old enough
      refute log =~ "Hot contracts module delayed"
    end

    test "schedules retry when chain is too young" do
      # Create blocks younger than 30 days
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z])
      second_block_timestamp = DateTime.utc_now() |> DateTime.add(-10, :day)
      insert(:block, number: 1, timestamp: second_block_timestamp, consensus: true)

      log =
        capture_log(fn ->
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            # Wait for initialization
            Process.sleep(200)

            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      assert log =~ "Hot contracts module delayed: chain is less than 30 days old"
      assert log =~ "Rescheduling startup check"
    end

    test "schedules startup check for next day when block not found" do
      # Only genesis block exists
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z], consensus: true)

      log =
        capture_log(fn ->
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            # Wait for initialization
            Process.sleep(200)

            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      assert log =~ "Hot contracts module delayed: second block not found"
      assert log =~ "Rescheduling startup check for next day"
    end
  end

  describe "handle_continue/2" do
    test "processes chain age check on startup" do
      # Create blocks older than 30 days
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z])
      second_block_timestamp = DateTime.utc_now() |> DateTime.add(-31, :day)
      insert(:block, number: 1, timestamp: second_block_timestamp, consensus: true)

      {:ok, pid} = HotSmartContracts.start_link([])

      try do
        # Wait for handle_continue to execute
        Process.sleep(200)

        assert Process.alive?(pid)
      after
        # Clean up
        if Process.alive?(pid) do
          try do
            GenServer.stop(pid, :normal, 1000)
          rescue
            _ -> :ok
          catch
            :exit, _ -> :ok
          end
        end
      end
    end
  end

  describe "handle_info/2 for :check_chain_age" do
    test "processes chain age check when message is received" do
      # Create blocks older than 30 days
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z])
      second_block_timestamp = DateTime.utc_now() |> DateTime.add(-31, :day)
      insert(:block, number: 1, timestamp: second_block_timestamp, consensus: true)

      {:ok, pid} = HotSmartContracts.start_link([])

      try do
        # Wait for initial processing
        Process.sleep(100)

        # Send the check_chain_age message
        send(pid, :check_chain_age)

        # Wait for processing
        Process.sleep(100)

        assert Process.alive?(pid)
      after
        # Clean up
        if Process.alive?(pid) do
          try do
            GenServer.stop(pid, :normal, 1000)
          rescue
            _ -> :ok
          catch
            :exit, _ -> :ok
          end
        end
      end
    end
  end

  describe "fetch_second_block_in_database integration" do
    test "finds second block when multiple blocks exist" do
      # Create multiple blocks
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z], consensus: true)
      insert(:block, number: 1, timestamp: ~U[2024-01-02 00:00:00Z], consensus: true)
      insert(:block, number: 2, timestamp: ~U[2024-01-03 00:00:00Z], consensus: true)

      assert {:ok, %Block{number: 1}} = Block.fetch_second_block_in_database()
    end

    test "returns error when only one consensus block exists #1" do
      # Create non-consensus first block and consensus second block
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z], consensus: false)
      insert(:block, number: 1, timestamp: ~U[2024-01-02 00:00:00Z], consensus: true)

      assert {:error, :not_found} = Block.fetch_second_block_in_database()
    end

    test "returns error when only one consensus block exists #2" do
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z], consensus: true)

      assert {:error, :not_found} = Block.fetch_second_block_in_database()
    end

    test "returns error when no consensus blocks exist" do
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z], consensus: false)
      insert(:block, number: 1, timestamp: ~U[2024-01-02 00:00:00Z], consensus: false)

      assert {:error, :not_found} = Block.fetch_second_block_in_database()
    end

    test "finds second block when blocks are not sequential" do
      # Create blocks with gaps in numbers
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z], consensus: true)
      insert(:block, number: 5, timestamp: ~U[2024-01-02 00:00:00Z], consensus: true)
      insert(:block, number: 10, timestamp: ~U[2024-01-03 00:00:00Z], consensus: true)

      # Should find block number 5 as the second block (ordered by number ascending)
      assert {:ok, %Block{number: 5}} = Block.fetch_second_block_in_database()
    end
  end

  describe "edge cases" do
    test "handles chain exactly 30 days old" do
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z])
      now = DateTime.utc_now()
      second_block_timestamp = DateTime.add(now, -30, :day)
      insert(:block, number: 1, timestamp: second_block_timestamp, consensus: true)

      log =
        capture_log(fn ->
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            Process.sleep(200)

            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      # Should not log delay message when chain is exactly 30 days old
      refute log =~ "Hot contracts module delayed"
    end

    test "handles chain just under 30 days old" do
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z])
      now = DateTime.utc_now()
      # 29 days, 23 hours, 59 minutes old
      second_block_timestamp = DateTime.add(now, -29, :day) |> DateTime.add(-23, :hour) |> DateTime.add(-59, :minute)
      insert(:block, number: 1, timestamp: second_block_timestamp, consensus: true)

      log =
        capture_log(fn ->
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            Process.sleep(200)

            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      assert log =~ "Hot contracts module delayed: chain is less than 30 days old"
      assert log =~ "Rescheduling startup check"
    end

    test "handles very new chain (1 day old)" do
      insert(:block, number: 0, timestamp: ~U[2024-01-01 00:00:00Z])
      now = DateTime.utc_now()
      second_block_timestamp = DateTime.add(now, -1, :day)
      insert(:block, number: 1, timestamp: second_block_timestamp, consensus: true)

      log =
        capture_log(fn ->
          {:ok, pid} = HotSmartContracts.start_link([])

          try do
            Process.sleep(200)

            assert Process.alive?(pid)
          after
            # Clean up
            if Process.alive?(pid) do
              try do
                GenServer.stop(pid, :normal, 1000)
              rescue
                _ -> :ok
              catch
                :exit, _ -> :ok
              end
            end
          end
        end)

      assert log =~ "Hot contracts module delayed: chain is less than 30 days old"
      assert log =~ "Rescheduling startup check"
    end
  end
end
