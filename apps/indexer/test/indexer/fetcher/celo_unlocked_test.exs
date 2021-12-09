defmodule Indexer.Fetcher.CeloUnlockedTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox
  import Explorer.Celo.CacheHelper

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.CeloUnlocked, as: ChainCeloUnlocked
  alias Indexer.Fetcher.CeloUnlocked

  @moduletag :capture_log

  setup :verify_on_exit!
  setup :set_mox_global

  @tag :skip
  describe "run/3" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      CeloUnlocked.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      :ok
    end

    test "imports the pending celo for the given address" do
      %Address{
        hash: %Hash{
          bytes: address
        }
      } = insert(:address, hash: "0xe26b6a5655601a9db347be8bd23dd7d4eabcf818")

      set_test_address("0x6cc083aed9e3ebe302a6336dbc7c921c9f03349e")

      stub(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [
                 %{
                   data: "0xf340c0d0000000000000000000000000e26b6a5655601a9db347be8bd23dd7d4eabcf818",
                   to: "0x6cc083aed9e3ebe302a6336dbc7c921c9f03349e"
                 },
                 "latest"
               ]
             }
           ],
           _options ->
          {
            :ok,
            [
              %{
                id: id,
                jsonrpc: "2.0",
                result:
                  "0x0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000a2bd4de46c65dc02c300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000061582bf1"
              }
            ]
          }
        end
      )

      CeloUnlocked.run(
        [%{address: address, retries_count: 0}],
        nil
      )

      assert Repo.one!(select(ChainCeloUnlocked, fragment("COUNT(*)"))) == 1
    end
  end
end
