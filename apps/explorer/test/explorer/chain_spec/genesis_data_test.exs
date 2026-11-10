# SPDX-License-Identifier: LicenseRef-Blockscout
# apps/explorer/test/explorer/chain_spec/geth/genesis_data.exs
defmodule Explorer.ChainSpec.GenesisDataTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  @besu_genesis "#{File.cwd!()}/test/support/fixture/chain_spec/qdai_genesis.json"
                |> File.read!()
                |> Utils.JSON.decode!()
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

  describe "local chain spec file validation" do
    setup do
      dir = Path.join(System.tmp_dir!(), "genesis_data_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf(dir) end)

      test_pid = self()

      :meck.new(Explorer.ChainSpec.Geth.Importer, [:passthrough])

      :meck.expect(Explorer.ChainSpec.Geth.Importer, :import_genesis_accounts, fn args ->
        send(test_pid, {:import_called, args})
        {:ok, []}
      end)

      %{dir: dir}
    end

    test "does not import a chain spec from a file with an extension other than .json", %{dir: dir} do
      path = Path.join(dir, "genesis.txt")
      File.write!(path, Utils.JSON.encode!(@besu_genesis))

      log = capture_log(fn -> fetch_genesis_data(path) end)

      assert log =~ "invalid_file_extension"
      refute_received {:import_called, _}
    end

    test "does not import a chain spec from a .json file with invalid JSON content", %{dir: dir} do
      path = Path.join(dir, "genesis.json")
      File.write!(path, "root:x:0:0:root:/root:/bin/bash")

      log = capture_log(fn -> fetch_genesis_data(path) end)

      assert log =~ "invalid_json_content"
      refute log =~ "root:x"
      refute_received {:import_called, _}
    end

    test "does not import a chain spec from a .json file holding a JSON scalar", %{dir: dir} do
      path = Path.join(dir, "genesis.json")
      File.write!(path, ~s("secret"))

      log = capture_log(fn -> fetch_genesis_data(path) end)

      assert log =~ "invalid_json_content"
      refute log =~ "secret"
      refute_received {:import_called, _}
    end
  end

  defp fetch_genesis_data(chain_spec_path) do
    env = Application.get_env(:explorer, Explorer.ChainSpec.GenesisData)

    Application.put_env(
      :explorer,
      Explorer.ChainSpec.GenesisData,
      Keyword.put(env, :chain_spec_path, chain_spec_path)
    )

    Explorer.ChainSpec.GenesisData.fetch_genesis_data() |> Task.await()
  end
end
