# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.DisabledFetchersTest do
  # `async: false` because the tests change the application environment
  use ExUnit.Case, async: false

  alias Indexer.Fetcher.{
    ContractCode,
    SignedAuthorizationStatus,
    Token,
    TokenBalance,
    TokenTotalSupplyUpdater,
    TokenUIMultiplierUpdater,
    UncleBlock
  }

  alias Indexer.PendingTransactionsSanitizer
  alias Indexer.Temporary.UnclesWithoutIndex

  @runtime_config_path Path.expand("../../../../../config/runtime.exs", __DIR__)

  # The environment variable and the module whose `disabled?/0` it controls.
  @disable_env_vars [
    {"INDEXER_DISABLE_TOKEN_FETCHER", Token.Supervisor},
    {"INDEXER_DISABLE_CURRENT_TOKEN_BALANCES_FETCHER", TokenBalance.Current.Supervisor},
    {"INDEXER_DISABLE_CONTRACT_CODE_FETCHER", ContractCode.Supervisor},
    {"INDEXER_DISABLE_SIGNED_AUTHORIZATION_STATUS_FETCHER", SignedAuthorizationStatus.Supervisor},
    {"INDEXER_DISABLE_UNCLE_BLOCK_FETCHER", UncleBlock.Supervisor},
    {"INDEXER_DISABLE_UNCLES_WITHOUT_INDEX_FETCHER", UnclesWithoutIndex.Supervisor},
    {"INDEXER_DISABLE_CATALOGED_TOKEN_UPDATER_FETCHER", TokenTotalSupplyUpdater},
    {"INDEXER_DISABLE_TOKEN_UI_MULTIPLIER_UPDATER_FETCHER", TokenUIMultiplierUpdater},
    {"INDEXER_DISABLE_PENDING_TRANSACTIONS_SANITIZER", PendingTransactionsSanitizer}
  ]

  # Sets `disabled?: true` for the given configuration key and restores the
  # initial configuration when the test exits.
  defp disable(config_key), do: put_disabled_flag(config_key, true)

  # Sets `disabled?` for the given configuration key and keeps the other
  # values of the key.
  defp put_disabled_flag(config_key, disabled?) do
    restore_config_on_exit(config_key)

    current_config = Application.get_env(:indexer, config_key) || []
    Application.put_env(:indexer, config_key, Keyword.put(current_config, :disabled?, disabled?))
  end

  # Restores the configuration key to its state before the first change in
  # the test. `Application.fetch_env/2` tells a missing key from a key with
  # the `nil` value, so that only a key that was missing is deleted.
  defp restore_config_on_exit(config_key) do
    if !Process.get({:restore_config_registered, config_key}) do
      Process.put({:restore_config_registered, config_key}, true)

      initial_config = Application.fetch_env(:indexer, config_key)

      on_exit(fn ->
        case initial_config do
          {:ok, value} -> Application.put_env(:indexer, config_key, value)
          :error -> Application.delete_env(:indexer, config_key)
        end
      end)
    end
  end

  # Evaluates `config/runtime.exs` with the current environment variables and
  # copies each `disabled?` value that it sets for the `:indexer` application
  # into the application environment. The configuration keys are taken from
  # the file, so a key that the code does not read has no effect here, as in
  # a real start of the application.
  defp apply_disabled_flags_from_runtime_config do
    @runtime_config_path
    |> Config.Reader.read!(env: :test, target: :host)
    |> Keyword.get(:indexer, [])
    |> Enum.filter(fn {_config_key, value} -> Keyword.keyword?(value) and Keyword.has_key?(value, :disabled?) end)
    |> Enum.each(fn {config_key, value} -> put_disabled_flag(config_key, value[:disabled?]) end)
  end

  defp set_env_var(name, value) do
    initial_value = System.get_env(name)

    if is_nil(value), do: System.delete_env(name), else: System.put_env(name, value)

    on_exit(fn ->
      if is_nil(initial_value), do: System.delete_env(name), else: System.put_env(name, initial_value)
    end)
  end

  describe "config/runtime.exs" do
    setup do
      # `config/runtime.exs` evaluates `config_helper.exs`, which defines a
      # module that is already loaded
      initial_ignore_module_conflict = Code.get_compiler_option(:ignore_module_conflict)
      Code.put_compiler_option(:ignore_module_conflict, true)

      on_exit(fn -> Code.put_compiler_option(:ignore_module_conflict, initial_ignore_module_conflict) end)

      Enum.each(@disable_env_vars, fn {env_var, _module} -> set_env_var(env_var, nil) end)
    end

    test "each INDEXER_DISABLE_* variable disables its fetcher" do
      apply_disabled_flags_from_runtime_config()

      for {env_var, module} <- @disable_env_vars do
        refute module.disabled?(), "#{inspect(module)} is disabled although #{env_var} is not set"
      end

      for {env_var, module} <- @disable_env_vars do
        System.put_env(env_var, "true")
        apply_disabled_flags_from_runtime_config()

        assert module.disabled?(), "#{env_var}=true does not disable #{inspect(module)}"

        System.delete_env(env_var)
      end
    end
  end

  describe "fetchers based on BufferedTask" do
    # None of the fetchers is started here, so a call that reaches
    # `BufferedTask.buffer` exits with `:noproc` and fails the test.

    test "Token.async_fetch/2 returns :ok when the fetcher is disabled" do
      disable(Token.Supervisor)

      assert Token.Supervisor.start_link([]) == :ignore
      assert Token.async_fetch([], true) == :ok
    end

    test "ContractCode.async_fetch/3 returns :ok when the fetcher is disabled" do
      disable(ContractCode.Supervisor)

      assert ContractCode.Supervisor.start_link([]) == :ignore
      assert ContractCode.async_fetch([], true) == :ok
    end

    test "SignedAuthorizationStatus.async_fetch/4 returns :ok when the fetcher is disabled" do
      disable(SignedAuthorizationStatus.Supervisor)

      assert SignedAuthorizationStatus.Supervisor.start_link([]) == :ignore
      assert SignedAuthorizationStatus.async_fetch([], [], true) == :ok
    end
  end

  describe "plain GenServer processes" do
    test "TokenTotalSupplyUpdater does not start when it is disabled" do
      disable(TokenTotalSupplyUpdater)

      assert TokenTotalSupplyUpdater.start_link([]) == :ignore
    end

    test "TokenUIMultiplierUpdater does not start when it is disabled" do
      disable(TokenUIMultiplierUpdater)

      assert TokenUIMultiplierUpdater.start_link([]) == :ignore
    end

    test "PendingTransactionsSanitizer does not start when it is disabled" do
      disable(PendingTransactionsSanitizer)

      assert PendingTransactionsSanitizer.start_link(json_rpc_named_arguments: []) == :ignore
    end
  end
end
