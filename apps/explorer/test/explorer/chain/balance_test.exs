defmodule Explorer.Chain.BalanceTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.Balance

  describe "changeset/2" do
    test "is valid with address_hash, block_number, and value" do
      params = params_for(:balance)

      assert %Changeset{valid?: true} = Balance.changeset(%Balance{}, params)
    end

    test "address_hash, block_number, and value is required" do
      assert %Changeset{valid?: false, errors: errors} = Balance.changeset(%Balance{}, %{})

      assert is_list(errors)
      assert length(errors) == 3
      assert Keyword.get_values(errors, :address_hash) == [{"can't be blank", [validation: :required]}]
      assert Keyword.get_values(errors, :block_number) == [{"can't be blank", [validation: :required]}]
      assert Keyword.get_values(errors, :value) == [{"can't be blank", [validation: :required]}]
    end
  end
end
