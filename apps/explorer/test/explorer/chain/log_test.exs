defmodule Explorer.Chain.LogTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.Log

  doctest Log

  describe "changeset/2" do
    test "accepts valid attributes" do
      params = params_for(:log, address_hash: build(:address).hash, transaction_hash: build(:transaction).hash)

      assert %Changeset{valid?: true} = Log.changeset(%Log{}, params)
    end

    test "rejects missing attributes" do
      params = params_for(:log, data: nil)
      changeset = Log.changeset(%Log{}, params)
      refute changeset.valid?
    end

    test "accepts optional attributes" do
      params =
        params_for(
          :log,
          address_hash: build(:address).hash,
          first_topic: "ham",
          transaction_hash: build(:transaction).hash
        )

      assert %Changeset{changes: %{first_topic: "ham"}, valid?: true} = Log.changeset(%Log{}, params)
    end

    test "assigns optional attributes" do
      params = Map.put(params_for(:log), :first_topic, "ham")
      changeset = Log.changeset(%Log{}, params)
      assert changeset.changes.first_topic === "ham"
    end
  end
end
