defmodule Explorer.Chain.TransactionTest do
  use Explorer.DataCase

  alias Explorer.Chain.Transaction

  describe "changeset/2" do
    test "with valid attributes" do
      changeset =
        Transaction.changeset(%Transaction{}, %{
          hash: "0x0",
          value: 1,
          gas: 21000,
          gas_price: 10000,
          input: "0x5c8eff12",
          nonce: "31337",
          public_key: "0xb39af9c",
          r: "0x9",
          s: "0x10",
          standard_v: "0x11",
          transaction_index: "0x12",
          v: "0x13"
        })

      assert changeset.valid?
    end

    test "with invalid attributes" do
      changeset = Transaction.changeset(%Transaction{}, %{racecar: "yellow ham"})
      refute changeset.valid?
    end

    test "it creates a new to address" do
      params = params_for(:transaction)
      to_address_params = %{hash: "sk8orDi3"}
      changeset_params = Map.merge(params, %{to_address: to_address_params})
      changeset = Transaction.changeset(%Transaction{}, changeset_params)
      assert changeset.valid?
    end
  end
end
