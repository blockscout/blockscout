defmodule Indexer.Fetcher.ValidatorsUpdaterTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Address
  alias Indexer.Fetcher.ValidatorsUpdater

  setup :verify_on_exit!
  setup :set_mox_global

  test "updates validators metadata on start" do
    %{address_hash: address_hash} = insert(:address_name, primary: true, metadata: %{active: true, type: "validator"})

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      1,
      fn [%{id: id}], _opts ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result:
               "0x546573746e616d65000000000000000000000000000000000000000000000000556e69746172696f6e000000000000000000000000000000000000000000000030303030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000140585800000000000000000000000000000000000000000000000000000000000030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003afe130e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000058585858585858207374726565742058585858585800000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
           }
         ]}
      end
    )

    pid = start_supervised!({ValidatorsUpdater, [%{update_interval: 1}, []]})

    Process.sleep(1_000)

    wait_for_results(fn ->
      updated = Repo.one!(from(n in Address.Name, where: n.address_hash == ^address_hash))

      assert updated.name == "Testname Unitarion"
    end)

    # Terminates the process so it finishes all Ecto processes.
    GenServer.stop(pid)
  end
end
