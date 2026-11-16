# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.ApplicationTest do
  use ExUnit.Case, async: false

  alias Explorer.Utility.AddressIdToAddressHash

  describe "children/0" do
    # Regression test: a mode-gated child spec placed in a list that is not
    # flattened reaches the supervisor as a bare `[]` outside its mode and
    # crashes the application on start. `Supervisor.init/2` runs the same
    # child validation as `Supervisor.start_link/2` without starting anything.
    for mode <- [:indexer, :api, :all] do
      test "every child is accepted by the supervisor in #{mode} mode" do
        initial_mode = Application.get_env(:explorer, :mode)
        Application.put_env(:explorer, :mode, unquote(mode))
        on_exit(fn -> Application.put_env(:explorer, :mode, initial_mode) end)

        children = Explorer.Application.children()
        refute Enum.empty?(children)

        assert {:ok, {_flags, specs}} = Supervisor.init(children, strategy: :one_for_one)
        assert length(specs) == length(children)
      end
    end

    test "the address id cache is a child only when its size limit is positive" do
      initial_config = Application.get_env(:explorer, AddressIdToAddressHash)

      on_exit(fn ->
        if initial_config,
          do: Application.put_env(:explorer, AddressIdToAddressHash, initial_config),
          else: Application.delete_env(:explorer, AddressIdToAddressHash)
      end)

      Application.put_env(:explorer, AddressIdToAddressHash, Keyword.merge(initial_config || [], cache_max_size: 1))
      assert AddressIdToAddressHash.Cache in Explorer.Application.children()

      Application.put_env(:explorer, AddressIdToAddressHash, Keyword.merge(initial_config || [], cache_max_size: 0))
      refute AddressIdToAddressHash.Cache in Explorer.Application.children()
    end
  end
end
