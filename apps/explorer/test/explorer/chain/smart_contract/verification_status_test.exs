# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.SmartContract.VerificationStatusTest do
  use Explorer.DataCase, async: true

  alias Explorer.Chain.SmartContract.VerificationStatus

  describe "set_pending_statuses_to_passed/1" do
    test "flips all pending rows for the address to passed and returns the count" do
      address = insert(:address)
      hash_string = to_string(address.hash)

      {:ok, _} = VerificationStatus.insert_status("uid-1", :pending, hash_string)
      {:ok, _} = VerificationStatus.insert_status("uid-2", :pending, hash_string)

      assert {2, nil} = VerificationStatus.set_pending_statuses_to_passed(address.hash)

      assert Repo.get_by(VerificationStatus, uid: "uid-1").status == 1
      assert Repo.get_by(VerificationStatus, uid: "uid-2").status == 1
    end

    test "accepts a 0x-prefixed string address" do
      address = insert(:address)
      {:ok, _} = VerificationStatus.insert_status("uid-1", :pending, to_string(address.hash))

      assert {1, nil} = VerificationStatus.set_pending_statuses_to_passed(to_string(address.hash))

      assert Repo.get_by(VerificationStatus, uid: "uid-1").status == 1
    end

    test "leaves already passed/failed rows and rows of other addresses untouched" do
      address = insert(:address)
      other_address = insert(:address)
      hash_string = to_string(address.hash)

      {:ok, _} = VerificationStatus.insert_status("pending", :pending, hash_string)
      {:ok, _} = VerificationStatus.insert_status("passed", :pass, hash_string)
      {:ok, _} = VerificationStatus.insert_status("failed", :fail, hash_string)
      {:ok, _} = VerificationStatus.insert_status("other", :pending, to_string(other_address.hash))

      assert {1, nil} = VerificationStatus.set_pending_statuses_to_passed(address.hash)

      assert Repo.get_by(VerificationStatus, uid: "pending").status == 1
      assert Repo.get_by(VerificationStatus, uid: "passed").status == 1
      assert Repo.get_by(VerificationStatus, uid: "failed").status == 2
      assert Repo.get_by(VerificationStatus, uid: "other").status == 0
    end

    test "returns {0, nil} when there are no pending rows for the address" do
      address = insert(:address)

      assert {0, nil} = VerificationStatus.set_pending_statuses_to_passed(address.hash)
    end

    test "returns {0, nil} for a nil or invalid address" do
      assert {0, nil} = VerificationStatus.set_pending_statuses_to_passed(nil)
      assert {0, nil} = VerificationStatus.set_pending_statuses_to_passed("not-an-address")
    end
  end
end
