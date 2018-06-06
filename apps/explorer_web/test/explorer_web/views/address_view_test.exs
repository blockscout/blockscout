defmodule ExplorerWeb.AddressViewTest do
  use ExplorerWeb.ConnCase, async: true

  alias Explorer.Chain.Data
  alias ExplorerWeb.AddressView
  alias Explorer.ExchangeRates.Token

  describe "contract?/1" do
    test "with a smart contract" do
      {:ok, code} = Data.cast("0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef")
      address = insert(:address, contract_code: code)
      assert AddressView.contract?(address)
    end

    test "with an account" do
      address = insert(:address, contract_code: nil)
      refute AddressView.contract?(address)
    end
  end

  describe "formatted_usd/2" do
    test "without a fetched_balance returns nil" do
      address = build(:address, fetched_balance: nil)
      token = %Token{usd_value: Decimal.new(0.5)}
      assert nil == AddressView.formatted_usd(address, token)
    end

    test "without a usd_value returns nil" do
      address = build(:address)
      token = %Token{usd_value: nil}
      assert nil == AddressView.formatted_usd(address, token)
    end

    test "returns formatted usd value" do
      address = build(:address, fetched_balance: 10_000_000_000_000)
      token = %Token{usd_value: Decimal.new(0.5)}
      assert "$0.000005 USD" == AddressView.formatted_usd(address, token)
    end
  end

  describe "qr_code/1" do
    test "it returns an encoded value" do
      address = build(:address)
      assert {:ok, _} = Base.decode64(AddressView.qr_code(address))
    end
  end
end
