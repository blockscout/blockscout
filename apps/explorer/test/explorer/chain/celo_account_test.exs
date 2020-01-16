defmodule Explorer.Chain.CeloAccountTest do
  use Explorer.DataCase

  alias Explorer.Chain.CeloAccount

  describe "changeset/2" do
    test "with valid attributes" do
      params = params_for(:celo_account)
      changeset = CeloAccount.changeset(%CeloAccount{}, params)
      assert changeset.valid?
    end

    test "with invalid attributes" do
      changeset = CeloAccount.changeset(%CeloAccount{}, %{address_foo: 0})
      refute changeset.valid?
    end
  end
end
