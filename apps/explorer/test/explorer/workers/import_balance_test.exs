defmodule Explorer.Workers.ImportBalanceTest do
  import Mock

  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Workers.ImportBalance

  use Explorer.DataCase

  describe "perform/1" do
    test "imports the balance for an address" do
      ImportBalance.perform("0x1d12e5716c593b156eb7152ca4360f6224ba3b0a")

      expected_balance = Decimal.new(1_572_374_181_095_000_000)

      assert {:ok, %Address{balance: ^expected_balance}} =
               Chain.hash_to_address("0x1d12e5716c593b156eb7152ca4360f6224ba3b0a")
    end
  end

  describe "perform_later/1" do
    test "delays the import of the balance for an address" do
      with_mock Exq,
        enqueue: fn _, _, _, _ ->
          insert(
            :address,
            hash: "0xskateboards",
            balance: 66
          )
        end do
        ImportBalance.perform_later("0xskateboards")

        expected_balance = Decimal.new(66)

        assert {:ok, %Address{balance: ^expected_balance}} = Chain.hash_to_address("0xskateboards")
      end
    end
  end
end
