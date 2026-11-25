# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.SmartContract.Solidity.PublisherWorkerTest do
  use Explorer.DataCase, async: true

  import ExUnit.CaptureLog

  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.SmartContract.VerificationStatus
  alias Explorer.SmartContract.Solidity.PublisherWorker

  describe "perform/1 for a contract already verified with a full match" do
    setup do
      address = insert(:address)
      insert(:smart_contract, address_hash: address.hash, partially_verified: false, contract_code_md5: "123")

      {:ok, hash_string: to_string(address.hash)}
    end

    test "marks the RPC verification attempt as passed without verifying", %{hash_string: hash_string} do
      uid = VerificationStatus.generate_uid(hash_string)

      PublisherWorker.perform({"json_api", %{"address_hash" => hash_string}, "{}", uid})

      assert Repo.get_by(VerificationStatus, uid: uid).status == 1
    end

    test "broadcasts a successful verification result without verifying", %{hash_string: hash_string} do
      Subscriber.to(:contract_verification_result, :on_demand)

      PublisherWorker.perform({"json_api_v2", %{"address_hash" => hash_string}, "{}"})

      assert_receive {:chain_event, :contract_verification_result, :on_demand, {^hash_string, {:ok, nil}}}
    end

    test "broadcasts a successful Sourcify verification result without verifying", %{hash_string: hash_string} do
      Subscriber.to(:contract_verification_result, :on_demand)

      PublisherWorker.perform({"sourcify_api_v2", hash_string, [], nil, nil})

      assert_receive {:chain_event, :contract_verification_result, :on_demand, {^hash_string, {:ok, nil}}}
    end
  end

  describe "on_failure/2" do
    test "marks the RPC verification attempt as failed" do
      hash_string = to_string(insert(:address).hash)
      uid = VerificationStatus.generate_uid(hash_string)
      {:ok, _} = VerificationStatus.insert_status(uid, :pending, hash_string)

      capture_log(fn ->
        PublisherWorker.on_failure({"json_api", %{"address_hash" => hash_string}, "{}", uid}, :boom)
      end)

      assert Repo.get_by(VerificationStatus, uid: uid).status == 2
    end

    test "broadcasts a failed verification result" do
      hash_string = to_string(insert(:address).hash)
      Subscriber.to(:contract_verification_result, :on_demand)

      capture_log(fn ->
        PublisherWorker.on_failure({"flattened_api_v2", %{"address_hash" => hash_string}}, :boom)
      end)

      assert_receive {:chain_event, :contract_verification_result, :on_demand,
                      {^hash_string, {:error, %Ecto.Changeset{valid?: false}}}}
    end

    test "only logs the crash of a job of another shape" do
      assert capture_log(fn -> PublisherWorker.on_failure({"", %{}, %{}, nil}, :boom) end) =~ "crashed"
    end
  end
end
