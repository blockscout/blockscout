# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Optimism.SuperchainConfigTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Optimism.SuperchainConfig

  @toml_factory "0xE5965Ab5962eDc7477C8520243A95517CD252fA9"
  @env_factory "0x05F9613aDB30026FFd634f38e5C4dFd30a197Fa1"

  setup do
    original_env = Application.get_env(:indexer, Indexer.Fetcher.Optimism, [])

    on_exit(fn ->
      Application.put_env(:indexer, Indexer.Fetcher.Optimism, original_env)
    end)

    toml_path =
      Path.join(System.tmp_dir!(), "superchain_config_test_#{System.unique_integer([:positive])}.toml")

    File.write!(toml_path, """
    name = "Test Chain"

    [addresses]
    SystemConfigProxy = "0x229047fed2591dbec1eF1118d64F7aF3dB9EB290"
    DisputeGameFactoryProxy = "#{@toml_factory}"
    """)

    on_exit(fn -> File.rm(toml_path) end)

    %{toml_path: toml_path}
  end

  describe "optimism_l1_dispute_game_factory_contract/0" do
    test "takes DisputeGameFactoryProxy from the Superchain config when the env is not set", %{toml_path: toml_path} do
      put_optimism_env(superchain_config_file_path: toml_path, optimism_l1_dispute_game_factory: nil)

      assert :ok = SuperchainConfig.refresh()
      assert SuperchainConfig.optimism_l1_dispute_game_factory_contract() == String.downcase(@toml_factory)
    end

    test "prefers the explicit env value over the Superchain config", %{toml_path: toml_path} do
      put_optimism_env(superchain_config_file_path: toml_path, optimism_l1_dispute_game_factory: @env_factory)

      assert :ok = SuperchainConfig.refresh()
      assert SuperchainConfig.optimism_l1_dispute_game_factory_contract() == String.downcase(@env_factory)
    end

    test "returns nil when neither the env nor the Superchain config defines the address" do
      put_optimism_env(superchain_config_file_path: nil, optimism_l1_dispute_game_factory: nil)

      assert :ok = SuperchainConfig.refresh()
      assert is_nil(SuperchainConfig.optimism_l1_dispute_game_factory_contract())
    end
  end

  defp put_optimism_env(overrides) do
    env =
      :indexer
      |> Application.get_env(Indexer.Fetcher.Optimism, [])
      |> Keyword.merge(overrides)

    Application.put_env(:indexer, Indexer.Fetcher.Optimism, env)
  end
end
