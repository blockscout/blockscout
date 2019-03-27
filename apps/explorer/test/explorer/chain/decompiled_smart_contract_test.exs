defmodule Explorer.Chain.DecompiledSmartContractTest do
  use Explorer.DataCase

  alias Explorer.Chain.DecompiledSmartContract

  describe "changeset/2" do
    test "with valid attributes" do
      params = params_for(:decompiled_smart_contract)
      changeset = DecompiledSmartContract.changeset(%DecompiledSmartContract{}, params)

      assert changeset.valid?
    end

    test "with invalid attributes" do
      changeset = DecompiledSmartContract.changeset(%DecompiledSmartContract{}, %{elixir: "erlang"})

      refute changeset.valid?
    end
  end
end
