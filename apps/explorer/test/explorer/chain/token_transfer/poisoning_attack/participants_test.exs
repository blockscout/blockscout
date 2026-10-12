# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.ParticipantsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.TokenTransfer.PoisoningAttack.Participants

  @eoa %{contract?: false, attributed?: false, verified?: false}

  describe "load/2" do
    test "is empty for no addresses" do
      assert Participants.load([]) == %{}
    end

    test "reports unknown and plain addresses as externally owned accounts" do
      unknown = address_hash()
      plain = insert(:address)

      assert Participants.load([unknown, plain.hash]) == %{unknown => @eoa, plain.hash => @eoa}
    end

    test "reports an unverified contract as a contract that is not attributed" do
      contract = insert(:contract_address)

      assert Participants.load([contract.hash]) == %{
               contract.hash => %{contract?: true, attributed?: false, verified?: false}
             }
    end

    test "reports a verified contract as attributed" do
      smart_contract = insert(:smart_contract)

      assert Participants.load([smart_contract.address_hash]) == %{
               smart_contract.address_hash => %{contract?: true, attributed?: true, verified?: true}
             }
    end

    test "reports a publicly tagged address as attributed" do
      tagged = insert(:address_to_tag)

      assert Participants.load([tagged.address_hash]) == %{
               tagged.address_hash => %{contract?: false, attributed?: true, verified?: false}
             }
    end

    test "reports a Safe and an EIP-7702 account as attributed, other proxies not" do
      safe = insert(:contract_address)
      delegated = insert(:address)
      minimal = insert(:contract_address)
      implementation = insert(:contract_address)

      insert(:proxy_implementation,
        proxy_address_hash: safe.hash,
        proxy_type: :master_copy,
        address_hashes: [implementation.hash],
        names: ["Safe"]
      )

      insert(:proxy_implementation,
        proxy_address_hash: delegated.hash,
        proxy_type: :eip7702,
        address_hashes: [implementation.hash],
        names: ["Delegate"]
      )

      insert(:proxy_implementation,
        proxy_address_hash: minimal.hash,
        proxy_type: :eip1167,
        address_hashes: [implementation.hash],
        names: ["Clone"]
      )

      participants = Participants.load([safe.hash, delegated.hash, minimal.hash])

      assert participants[safe.hash] == %{contract?: true, attributed?: true, verified?: false}
      assert participants[delegated.hash] == %{contract?: false, attributed?: true, verified?: false}
      assert participants[minimal.hash] == %{contract?: true, attributed?: false, verified?: false}
    end
  end
end
