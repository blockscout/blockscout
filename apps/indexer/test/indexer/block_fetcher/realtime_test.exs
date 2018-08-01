defmodule Indexer.BlockFetcher.RealtimeTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.{Address, Block}
  alias Indexer.{BlockFetcher, Sequence}
  alias Indexer.BlockFetcher.Realtime

  @moduletag capture_log: true

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
    core_json_rpc_named_arguments =
      json_rpc_named_arguments
      |> put_in([:transport_options, :url], "https://core.poa.network")
      |> put_in(
        [:transport_options, :method_to_url],
        eth_getBalance: "https://core-trace.poa.network",
        trace_replayTransaction: "https://core-trace.poa.network"
      )

    block_fetcher = %{BlockFetcher.new(json_rpc_named_arguments: core_json_rpc_named_arguments) | broadcast: false}
    realtime = Realtime.new(%{block_fetcher: block_fetcher, block_interval: 5_000})

    %{json_rpc_named_arguments: core_json_rpc_named_arguments, realtime: realtime}
  end

  describe "Indexer.BlockFetcher.stream_import/1" do
    @tag :no_geth
    test "in range with internal transactions", %{realtime: %Realtime{block_fetcher: %BlockFetcher{} = block_fetcher}} do
      {:ok, sequence} = Sequence.start_link(ranges: [], step: 2)
      Sequence.cap(sequence)
      full_block_fetcher = %BlockFetcher{block_fetcher | sequence: sequence}

      assert {:ok,
              %{
                addresses: [
                  %Address{hash: first_address_hash, fetched_balance_block_number: 3_946_079},
                  %Address{hash: second_address_hash, fetched_balance_block_number: 3_946_079},
                  %Address{hash: third_address_hash, fetched_balance_block_number: 3_946_079},
                  %Address{hash: fourth_address_hash, fetched_balance_block_number: 3_946_080},
                  %Address{hash: fifth_address_hash, fetched_balance_block_number: 3_946_079}
                ],
                balances: [
                  %{
                    address_hash: first_address_hash,
                    block_number: 3_946_079
                  },
                  %{
                    address_hash: second_address_hash,
                    block_number: 3_946_079
                  },
                  %{
                    address_hash: third_address_hash,
                    block_number: 3_946_079
                  },
                  %{
                    address_hash: fourth_address_hash,
                    block_number: 3_946_080
                  },
                  %{
                    address_hash: fifth_address_hash,
                    block_number: 3_946_079
                  }
                ],
                blocks: [%Block{number: 3_946_079}, %Block{number: 3_946_080}],
                internal_transactions: [
                  %{index: 0, transaction_hash: transaction_hash},
                  %{index: 1, transaction_hash: transaction_hash},
                  %{index: 2, transaction_hash: transaction_hash},
                  %{index: 3, transaction_hash: transaction_hash},
                  %{index: 4, transaction_hash: transaction_hash},
                  %{index: 5, transaction_hash: transaction_hash}
                ],
                logs: [],
                transactions: [transaction_hash]
              }} = BlockFetcher.import_range(full_block_fetcher, 3_946_079..3_946_080)
    end
  end
end
