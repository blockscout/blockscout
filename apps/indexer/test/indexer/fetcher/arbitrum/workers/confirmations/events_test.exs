# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.EventsTest do
    use Explorer.DataCase

    alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents
    alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Events

    @log_start 100
    @log_end 200

    describe "fetch_and_sort_confirmations_logs/4" do
      test "skips genesis SendRootUpdated and keeps other confirmed block numbers" do
        genesis_block = insert(:block, number: 0)
        batch = insert(:arbitrum_l1_batch, start_block: 1, end_block: 10)
        confirmed_block = insert(:block, number: 8)

        insert(:arbitrum_batch_block,
          batch_number: batch.number,
          block_number: confirmed_block.number
        )

        cache =
          confirmation_logs_cache([
            send_root_updated_log(genesis_block.hash),
            send_root_updated_log(confirmed_block.hash)
          ])

        assert {:ok, [8], ^cache, 2} =
                 Events.fetch_and_sort_confirmations_logs(
                   @log_start,
                   @log_end,
                   outbox_config(),
                   cache
                 )
      end

      test "returns ok with empty list when only genesis SendRootUpdated is present" do
        genesis_block = insert(:block, number: 0)

        cache = confirmation_logs_cache([send_root_updated_log(genesis_block.hash)])

        assert {:ok, [], ^cache, 1} =
                 Events.fetch_and_sort_confirmations_logs(
                   @log_start,
                   @log_end,
                   outbox_config(),
                   cache
                 )
      end

      test "returns error when rollup block hash is not indexed yet" do
        missing_hash = "0x" <> String.duplicate("1", 64)
        cache = confirmation_logs_cache([send_root_updated_log(missing_hash)])

        assert {:error, nil, ^cache, 1} =
                 Events.fetch_and_sort_confirmations_logs(
                   @log_start,
                   @log_end,
                   outbox_config(),
                   cache
                 )
      end

      test "returns error when indexed non-genesis block has no batch association" do
        unbatched_block = insert(:block, number: 5)
        cache = confirmation_logs_cache([send_root_updated_log(unbatched_block.hash)])

        assert {:error, nil, ^cache, 1} =
                 Events.fetch_and_sort_confirmations_logs(
                   @log_start,
                   @log_end,
                   outbox_config(),
                   cache
                 )
      end
    end

    defp outbox_config do
      %{
        outbox_address: "0x" <> String.duplicate("0", 40),
        json_rpc_named_arguments: []
      }
    end

    defp confirmation_logs_cache(logs) do
      %{
        {@log_start, @log_end} => logs
      }
    end

    defp send_root_updated_log(rollup_block_hash) do
      %{
        "transactionHash" => "0x" <> String.duplicate("a", 64),
        "topics" => [
          ArbitrumEvents.send_root_updated(),
          "0x" <> String.duplicate("b", 64),
          hash_to_topic(rollup_block_hash)
        ]
      }
    end

    defp hash_to_topic(%Explorer.Chain.Hash{} = hash), do: to_string(hash)
    defp hash_to_topic(hash) when is_binary(hash), do: hash
  end
end
