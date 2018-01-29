defmodule Explorer.FromAddressTest do
  use Explorer.DataCase
  alias Explorer.FromAddress

  describe "changeset/2" do
    test "with valid attributes" do
      params = params_for(:from_address)
      changeset = FromAddress.changeset(%FromAddress{}, params)
      assert changeset.valid?
    end
  end
end
