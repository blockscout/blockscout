defmodule Explorer.AddressFormTest do
  use Explorer.DataCase
  alias Explorer.AddressForm

  describe "build/1" do
    test "that it has a balance" do
      address = insert(:address, %{hash: "bert"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "bert", from: "ernie"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "bert", from: "kermit"})

      assert AddressForm.build(address).balance == Decimal.new(10)
    end
  end

  describe "calculate_balance/1" do
    test "when there are more credits than debits it returns a positive value" do
      address = insert(:address, %{hash: "bert"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "bert", from: "ernie"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "bert", from: "kermit"})

      assert AddressForm.calculate_balance(address) == Decimal.new(10)
    end

    test "when credits and debits are equal it returns zero" do
      address = insert(:address, %{hash: "bert"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "bert", from: "ernie"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "ernie", from: "bert"})

      assert AddressForm.calculate_balance(address) == Decimal.new(0)
    end

    test "when there are more debits than credits it returns a negative value" do
      address = insert(:address, %{hash: "bert"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "ernie", from: "bert"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "ernie", from: "bert"})

      assert AddressForm.calculate_balance(address) ==  Decimal.new(-10)
    end
  end

  describe "credits/1" do
    test "when there are no transactions" do
      address = insert(:address, %{hash: "bert"})
      assert AddressForm.credits(address) == Decimal.new(0)
    end

    test "that it calculates credits" do
      address = insert(:address, %{hash: "bert"})
      insert(:transaction, value: 5) |> with_addresses(%{from: "ernie", to: "bert"})
      insert(:transaction, value: 5) |> with_addresses(%{from: "bert", to: "kermit"})
      insert(:transaction, value: 5) |> with_addresses(%{from: "janice", to: "bert"})

      assert AddressForm.credits(address) == Decimal.new(10)
    end
  end

  describe "debits/1" do
    test "when there are no transactions" do
      address = insert(:address, %{hash: "bert"})
      assert AddressForm.debits(address) == Decimal.new(0)
    end

    test "that it calculates debits" do
      address = insert(:address, %{hash: "ernie"})
      insert(:transaction, value: 5) |> with_addresses(%{from: "ernie", to: "bert"})
      insert(:transaction, value: 5) |> with_addresses(%{from: "ernie", to: "kermit"})
      insert(:transaction, value: 5) |> with_addresses(%{from: "janice", to: "ernie"})

      assert AddressForm.debits(address) == Decimal.new(10)
    end
  end
end
