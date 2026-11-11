# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.DisabledFetchersTest do
  # `async: false` because the tests change the application environment
  use ExUnit.Case, async: false

  alias Indexer.Fetcher.{
    ContractCode,
    SignedAuthorizationStatus,
    Token,
    TokenTotalSupplyUpdater,
    TokenUIMultiplierUpdater
  }

  alias Indexer.PendingTransactionsSanitizer

  # Sets `disabled?: true` for the given configuration key and restores the
  # initial configuration when the test exits.
  defp disable(config_key) do
    initial_config = Application.get_env(:indexer, config_key)

    Application.put_env(:indexer, config_key, Keyword.put(initial_config || [], :disabled?, true))

    on_exit(fn ->
      if is_nil(initial_config) do
        Application.delete_env(:indexer, config_key)
      else
        Application.put_env(:indexer, config_key, initial_config)
      end
    end)
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
      assert TokenTotalSupplyUpdater.add_tokens(["0x0000000000000000000000000000000000000001"]) == :ok
    end

    test "TokenUIMultiplierUpdater does not start when it is disabled" do
      disable(TokenUIMultiplierUpdater)

      assert TokenUIMultiplierUpdater.start_link([]) == :ignore
      assert TokenUIMultiplierUpdater.add_changes([%{token_contract_address_hash: "0x01"}]) == :ok
    end

    test "PendingTransactionsSanitizer does not start when it is disabled" do
      disable(PendingTransactionsSanitizer)

      assert PendingTransactionsSanitizer.start_link(json_rpc_named_arguments: []) == :ignore
    end
  end
end
