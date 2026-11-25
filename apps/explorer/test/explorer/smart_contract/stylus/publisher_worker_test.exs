# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.SmartContract.Stylus.PublisherWorkerTest do
  use Explorer.DataCase, async: true

  import ExUnit.CaptureLog

  alias Explorer.Chain.Events.Subscriber
  alias Explorer.SmartContract.Stylus.PublisherWorker

  describe "perform/1" do
    test "broadcasts a successful result without verifying a contract already verified with a full match" do
      address = insert(:address)
      insert(:smart_contract, address_hash: address.hash, partially_verified: false, contract_code_md5: "123")
      hash_string = to_string(address.hash)
      Subscriber.to(:contract_verification_result, :on_demand)

      PublisherWorker.perform({"github_repository", %{"address_hash" => hash_string}})

      assert_receive {:chain_event, :contract_verification_result, :on_demand, {^hash_string, {:ok, nil}}}
    end
  end

  describe "on_failure/2" do
    test "broadcasts a failed verification result" do
      hash_string = to_string(insert(:address).hash)
      Subscriber.to(:contract_verification_result, :on_demand)

      capture_log(fn ->
        PublisherWorker.on_failure({"github_repository", %{"address_hash" => hash_string}}, :boom)
      end)

      assert_receive {:chain_event, :contract_verification_result, :on_demand,
                      {^hash_string, {:error, %Ecto.Changeset{valid?: false}}}}
    end

    test "only logs the crash of a job of another shape" do
      assert capture_log(fn -> PublisherWorker.on_failure({"unknown", %{}}, :boom) end) =~ "crashed"
    end
  end
end
