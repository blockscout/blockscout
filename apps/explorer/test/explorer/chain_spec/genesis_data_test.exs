# apps/explorer/test/explorer/chain_spec/geth/genesis_data.exs
defmodule Explorer.ChainSpec.GenesisDataTest do
  use ExUnit.Case, async: false

  @besu_genesis "#{File.cwd!()}/test/support/fixture/chain_spec/qdai_genesis.json"
                |> File.read!()
                |> Jason.decode!()
  setup do
    # Patch application env
    old_genesis_data = Application.get_env(:explorer, Explorer.ChainSpec.GenesisData)

    old_json_rpc_named_arguments =
      Application.get_env(:indexer, :json_rpc_named_arguments)

    Application.put_env(
      :explorer,
      Explorer.ChainSpec.GenesisData,
      Keyword.merge(old_genesis_data,
        chain_spec_path: "#{File.cwd!()}/test/support/fixture/chain_spec/qdai_genesis.json",
        precompiled_config_path: nil
      )
    )

    Application.put_env(
      :indexer,
      :json_rpc_named_arguments,
      Keyword.merge(old_json_rpc_named_arguments, variant: EthereumJSONRPC.Besu)
    )

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.ChainSpec.GenesisData, old_genesis_data)
      Application.put_env(:indexer, :json_rpc_named_arguments, old_json_rpc_named_arguments)
      :meck.unload()
    end)

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
