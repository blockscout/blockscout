defmodule Indexer.Fetcher.PendingCeloTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox
  import Explorer.Celo.CacheHelper

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.PendingCelo, as: ChainPendingCelo
  alias Indexer.Fetcher.PendingCelo

  @moduletag :capture_log

  setup :verify_on_exit!
  setup :set_mox_global

  describe "run/3" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      PendingCelo.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      :ok
    end

    test "imports the pending celo for the given address" do
      %Address{
        hash: %Hash{bytes: address}
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
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result:
                 "0x0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000a2bd4de46c65dc02c300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000061582bf1"
             }
           ]}
        end
      )

      assert PendingCelo.run(
               [%{address: address, retries_count: 0}],
               nil
             ) ==
               {:retry,
                [
                  %{
                    address:
                      <<226, 107, 106, 86, 85, 96, 26, 157, 179, 71, 190, 139, 210, 61, 215, 212, 234, 188, 248, 24>>,
                    retries_count: 1,
                    pending: [
                      %{
                        address:
                          <<226, 107, 106, 86, 85, 96, 26, 157, 179, 71, 190, 139, 210, 61, 215, 212, 234, 188, 248,
                            24>>,
                        amount: 3_002_013_349_941_538_980_547,
                        timestamp: 1_633_168_369
                      }
                    ]
                  }
                ]}

      Explorer.Repo.get_by(ChainPendingCelo, account_address: address)
    end
  end
end
