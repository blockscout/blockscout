# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.compile_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.TasksTest do
    use Explorer.DataCase

    import ExUnit.CaptureLog

    alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Tasks, as: ConfirmationsTasks

    describe "historical_confirmations_discovery_completed?/1" do
      test "returns true and logs completion when end_block is below the lowest L1 block" do
        state = state_with(end_block: 9, lowest_l1_block_for_confirmations: 10)

        log =
          capture_log(fn ->
            assert ConfirmationsTasks.historical_confirmations_discovery_completed?(state) == true
          end)

        assert log =~ "Historical confirmations discovery completed"
        assert log =~ "10"
      end

      test "returns false and logs nothing when end_block is at the lowest L1 block" do
        state = state_with(end_block: 10, lowest_l1_block_for_confirmations: 10)

        log =
          capture_log(fn ->
            assert ConfirmationsTasks.historical_confirmations_discovery_completed?(state) == false
          end)

        assert log == ""
      end

      test "returns false and logs nothing when end_block is above the lowest L1 block" do
        state = state_with(end_block: 11, lowest_l1_block_for_confirmations: 10)

        log =
          capture_log(fn ->
            assert ConfirmationsTasks.historical_confirmations_discovery_completed?(state) == false
          end)

        assert log == ""
      end

      test "returns false and logs nothing when end_block is nil" do
        state = state_with(end_block: nil, lowest_l1_block_for_confirmations: 10)

        log =
          capture_log(fn ->
            assert ConfirmationsTasks.historical_confirmations_discovery_completed?(state) == false
          end)

        assert log == ""
      end
    end

    defp state_with(end_block: end_block, lowest_l1_block_for_confirmations: lowest_l1_block_for_confirmations) do
      %{
        config: %{
          l1_rollup_init_block: 1,
          rollup_first_block: 1
        },
        task_data: %{
          historical_confirmations: %{
            end_block: end_block,
            start_block: nil,
            lowest_l1_block_for_confirmations: lowest_l1_block_for_confirmations
          }
        }
      }
    end
  end
end
