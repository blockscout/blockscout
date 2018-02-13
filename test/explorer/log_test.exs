defmodule Explorer.LogTest do
  use Explorer.DataCase

  alias Explorer.Log

  describe "changeset/2" do
    test "accepts valid attributes" do
      params = params_for(:log)
      changeset = Log.changeset(%Log{}, params)
      assert changeset.valid?
    end

    test "rejects missing attributes" do
      params = params_for(:log, data: nil)
      changeset = Log.changeset(%Log{}, params)
      refute changeset.valid?
    end
  end
end
