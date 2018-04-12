defmodule Explorer.ToAddressTest do
  use Explorer.DataCase
  alias Explorer.ToAddress

  describe "changeset/2" do
    test "with valid attributes" do
      params = params_for(:to_address)
      changeset = ToAddress.changeset(%ToAddress{}, params)
      assert changeset.valid?
    end
  end
end
