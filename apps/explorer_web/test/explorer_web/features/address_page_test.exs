defmodule ExplorerWeb.AddressPageTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query, only: [css: 2]

  alias Explorer.Chain.{Credit, Debit}
  alias ExplorerWeb.AddressPage

  setup do
    block =
      insert(:block, %{
        number: 555,
        timestamp: Timex.now() |> Timex.shift(hours: -2),
        gas_used: 123_987
      })

    for _ <- 0..3, do: insert(:transaction) |> with_block(block)
    insert(:transaction, hash: "0xC001", gas: 5891) |> with_block

    lincoln = insert(:address, hash: "0xlincoln")
    taft = insert(:address, hash: "0xhowardtaft")

    transaction =
      insert(
        :transaction,
        hash: "0xSk8",
        value: Explorer.Chain.Wei.from(Decimal.new(5656), :ether),
        gas: Decimal.new(1_230_000_000_000_123_123),
        gas_price: Decimal.new(7_890_000_000_898_912_300_045),
        input: "0x00012",
        nonce: 99045,
        inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
        updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"),
        from_address_id: taft.id,
        to_address_id: lincoln.id
      )

    insert(:block_transaction, block: block, transaction: transaction)

    receipt = insert(:receipt, transaction: transaction, status: 1)
    insert(:log, address_id: lincoln.id, receipt: receipt)

    # From Lincoln to Taft.
    txn_from_lincoln =
      insert(
        :transaction,
        hash: "0xrazerscooter",
        from_address_id: lincoln.id,
        to_address_id: taft.id
      )

    insert(:block_transaction, block: block, transaction: txn_from_lincoln)

    insert(:receipt, transaction: txn_from_lincoln)

    Credit.refresh()
    Debit.refresh()

    {:ok, %{address: lincoln, transaction: transaction}}
  end

  test "viewing address overview information", %{session: session} do
    insert(:address, hash: "0xthinmints", balance: 500)

    session
    |> visit("/en/addresses/0xthinmints")
    |> assert_has(css(".address__balance", text: "0.000,000,000,000,000,500 POA"))
  end

  describe "viewing transactions" do
    test "sees all addresses transactions by default", %{address: address, session: session} do
      session
      |> AddressPage.visit_page(address.hash)
      |> assert_has(AddressPage.transaction("0xSk8"))
      |> assert_has(AddressPage.transaction("0xrazerscooter"))
    end

    test "can filter to only see transactions to an address", %{address: address, session: session} do
      session
      |> visit("/en/addresses/#{address.hash}")
      |> click(css("[data-test='filter_dropdown']", text: "Filter: All"))
      |> click(css(".address__link", text: "To"))
      |> assert_has(css(".transactions__link--long-hash", text: "0xSk8"))
      |> refute_has(css(".transactions__link--long-hash", text: "0xrazerscooter"))
    end

    test "can filter to only see transactions from an address", %{address: address, session: session} do
      session
      |> visit("/en/addresses/#{address.hash}")
      |> click(css("[data-test='filter_dropdown']", text: "Filter: All"))
      |> click(css(".address__link", text: "From"))
      |> assert_has(css(".transactions__link--long-hash", text: "0xrazerscooter"))
      |> refute_has(css(".transactions__link--long-hash", text: "0xSk8"))
    end
  end

  describe "viewing internal transactions" do
    setup %{address: address, transaction: transaction} do
      insert(:internal_transaction, transaction_id: transaction.id, to_address_id: address.id)
      insert(:internal_transaction, transaction_id: transaction.id, from_address_id: address.id)
      :ok
    end

    test "can see internal transactions for an address", %{address: address, session: session} do
      session
      |> AddressPage.visit_page(address.hash)
      |> AddressPage.click_internal_transactions()
      |> assert_has(AddressPage.internal_transactions(count: 2))
    end

    test "can filter to only see internal transactions from an address", %{addresses: addresses, session: session} do
      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> AddressPage.click_internal_transactions()
      |> AddressPage.apply_filter("From")
      |> assert_has(AddressPage.internal_transactions(count: 1))
    end

    test "can filter to only see internal transactions to an address", %{addresses: addresses, session: session} do
      session
      |> AddressPage.visit_page(address.hash)
      |> AddressPage.click_internal_transactions()
      |> AddressPage.apply_filter("To")
      |> assert_has(AddressPage.internal_transactions(count: 1))
    end
  end
end
