# apps/explorer/test/explorer/chain_spec/geth/genesis_data.exs
defmodule Explorer.ChainSpec.GenesisDataTest do
  use ExUnit.Case, async: false

  @besu_genesis "#{File.cwd!()}/test/support/fixture/chain_spec/qdai_genesis.json"
                |> File.read!()
                |> Jason.decode!()
  setup do
    # Patch application env
    Application.put_env(:explorer, Explorer.ChainSpec.GenesisData,
      chain_spec_path: "#{File.cwd!()}/test/support/fixture/chain_spec/qdai_genesis.json",
      precompiled_config_path: nil
    )

    Application.put_env(:indexer, :json_rpc_named_arguments, variant: EthereumJSONRPC.Besu)

    on_exit(fn -> :meck.unload() end)

    :ok
  end

  test "remaps Besu variant to Geth and calls GethImporter.import_genesis_accounts/1" do
    test_pid = self()

    :meck.new(Explorer.ChainSpec.Geth.Importer, [:passthrough])
    :meck.expect(Explorer.ChainSpec.Geth.Importer, :import_genesis_accounts, fn args ->
      send(test_pid, {:import_called, args})
      {:ok, []}
    end)

    Explorer.ChainSpec.GenesisData.fetch_genesis_data()

    assert_receive {:import_called, @besu_genesis}, 1000
  end
end
