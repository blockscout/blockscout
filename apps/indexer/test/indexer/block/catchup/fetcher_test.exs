defmodule Indexer.Block.Catchup.FetcherTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Indexer.{Block, CoinBalance, InternalTransaction, Token, TokenBalance}
  alias Indexer.Block.Catchup.Fetcher

  @moduletag capture_log: true

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup do
    # Uncle don't occur on POA chains, so there's no way to test this using the public addresses, so mox-only testing
    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.Mox,
        transport_options: [],
        # Which one does not matter, so pick one
        variant: EthereumJSONRPC.Parity
      ]
    }
  end

  describe "import/1" do
    test "fetches uncles asynchronously", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      parent = self()

      pid =
        spawn_link(fn ->
          receive do
            {:"$gen_call", from, {:buffer, uncles}} ->
              GenServer.reply(from, :ok)
              send(parent, {:uncles, uncles})
          end
        end)

      Process.register(pid, Block.Uncle.Fetcher)

      nephew_hash = block_hash() |> to_string()
      uncle_hash = block_hash() |> to_string()
      miner_hash = address_hash() |> to_string()
      block_number = 0

      assert {:ok, _} =
               Fetcher.import(%Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments}, %{
                 addresses: %{
                   params: [
                     %{hash: miner_hash}
                   ]
                 },
                 address_hash_to_fetched_balance_block_number: %{miner_hash => block_number},
                 balances: %{
                   params: [
                     %{
                       address_hash: miner_hash,
                       block_number: block_number
                     }
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       difficulty: 0,
                       gas_limit: 21000,
                       gas_used: 21000,
                       miner_hash: miner_hash,
                       nonce: 0,
                       number: block_number,
                       parent_hash:
                         block_hash()
                         |> to_string(),
                       size: 0,
                       timestamp: DateTime.utc_now(),
                       total_difficulty: 0,
                       hash: nephew_hash
                     }
                   ]
                 },
                 block_second_degree_relations: %{
                   params: [
                     %{
                       nephew_hash: nephew_hash,
                       uncle_hash: uncle_hash
                     }
                   ]
                 },
                 tokens: %{
                   params: [],
                   on_conflict: :nothing
                 },
                 token_balances: %{
                   params: []
                 },
                 transactions: %{
                   params: [],
                   on_conflict: :nothing
                 },
                 transaction_hash_to_block_number: %{}
               })

      assert_receive {:uncles, [^uncle_hash]}
    end
  end
end
