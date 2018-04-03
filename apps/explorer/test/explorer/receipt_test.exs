defmodule Explorer.ReceiptTest do
  use Explorer.DataCase

  alias Explorer.Receipt

  describe "changeset/2" do
    test "accepts valid attributes" do
      transaction = insert(:transaction)
      params = params_for(:receipt, transaction: transaction)
      changeset = Receipt.changeset(%Receipt{}, params)
      assert changeset.valid?
    end

    test "rejects missing attributes" do
      transaction = insert(:transaction)
      params = params_for(:receipt, transaction: transaction, cumulative_gas_used: nil)
      changeset = Receipt.changeset(%Receipt{}, params)
      refute changeset.valid?
    end

    test "accepts logs" do
      transaction = insert(:transaction)
      address = insert(:address)
      log_params = params_for(:log, address: address)
      params = params_for(:receipt, transaction: transaction, logs: [log_params])
      changeset = Receipt.changeset(%Receipt{}, params)
      assert changeset.valid?
    end

    test "saves logs for the receipt" do
      transaction = insert(:transaction)
      address = insert(:address)
      log_params = params_for(:log, address: address)
      params = params_for(:receipt, transaction: transaction, logs: [log_params])
      changeset = Receipt.changeset(%Receipt{}, params)
      receipt = Repo.insert!(changeset) |> Repo.preload(logs: :address)
      assert List.first(receipt.logs).address == address
    end
  end
end
