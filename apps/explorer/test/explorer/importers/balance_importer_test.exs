defmodule Explorer.BalanceImporterTest do
  use Explorer.DataCase

  alias Explorer.Address.Service, as: Address
  alias Explorer.BalanceImporter

  describe "import/1" do
    test "it updates the balance for an address" do
      insert(:address, hash: "0x5cc18cc34175d358ff8e19b7f98566263c4106a0", balance: 5)
      BalanceImporter.import("0x5cc18cc34175d358ff8e19b7f98566263c4106a0")
      address = Address.by_hash("0x5cc18cc34175d358ff8e19b7f98566263c4106a0")
      assert address.balance == Decimal.new(1_572_374_181_095_000_000)
    end

    test "it updates the balance update time for an address" do
      insert(
        :address,
        hash: "0x5cc18cc34175d358ff8e19b7f98566263c4106a0",
        balance_updated_at: nil
      )

      BalanceImporter.import("0x5cc18cc34175d358ff8e19b7f98566263c4106a0")
      address = Address.by_hash("0x5cc18cc34175d358ff8e19b7f98566263c4106a0")
      refute is_nil(address.balance_updated_at)
    end

    test "it creates an address if one does not exist" do
      BalanceImporter.import("0x5cc18cc34175d358ff8e19b7f98566263c4106a0")
      assert Address.by_hash("0x5cc18cc34175d358ff8e19b7f98566263c4106a0")
    end
  end
end
