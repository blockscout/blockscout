defmodule ExplorerWeb.AddressPageTest do
  use ExplorerWeb.FeatureCase, async: true

  alias ExplorerWeb.AddressPage

  setup do
    block = insert(:block)

    lincoln = insert(:address)
    taft = insert(:address)

    from_taft =
      :transaction
      |> insert(from_address_id: taft.id, to_address_id: lincoln.id)
      |> with_block(block)
      |> with_receipt()

    from_lincoln =
      :transaction
      |> insert(from_address_id: lincoln.id, to_address_id: taft.id)
      |> with_block(block)
      |> with_receipt()

    {:ok,
     %{
       transactions: %{from_lincoln: from_lincoln, from_taft: from_taft},
       addresses: %{lincoln: lincoln, taft: taft}
     }}
  end

  test "viewing address overview information", %{session: session} do
    address = insert(:address, balance: 500)

    session
    |> AddressPage.visit_page(address)
    |> assert_text(AddressPage.balance(), "0.000,000,000,000,000,500 POA")
  end

  describe "viewing transactions" do
    test "sees all addresses transactions by default", %{
      addresses: addresses,
      session: session,
      transactions: transactions
    } do
      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> assert_has(AddressPage.transaction(transactions.from_taft))
      |> assert_has(AddressPage.transaction(transactions.from_lincoln))
    end

    test "can filter to only see transactions from an address", %{
      addresses: addresses,
      session: session,
      transactions: transactions
    } do
      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> AddressPage.apply_filter("From")
      |> assert_has(AddressPage.transaction(transactions.from_lincoln))
      |> refute_has(AddressPage.transaction(transactions.from_taft))
    end

    test "can filter to only see transactions to an address", %{
      addresses: addresses,
      session: session,
      transactions: transactions
    } do
      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> AddressPage.apply_filter("To")
      |> refute_has(AddressPage.transaction(transactions.from_lincoln))
      |> assert_has(AddressPage.transaction(transactions.from_taft))
    end
  end

  describe "viewing internal transactions" do
    setup %{addresses: addresses, transactions: transactions} do
      address_id = addresses.lincoln.id
      transaction_id = transactions.from_lincoln.id
      insert(:internal_transaction, transaction_id: transaction_id, to_address_id: address_id, index: 0)
      insert(:internal_transaction, transaction_id: transaction_id, from_address_id: address_id, index: 1)
      :ok
    end

    test "can see internal transactions for an address", %{addresses: addresses, session: session} do
      session
      |> AddressPage.visit_page(addresses.lincoln)
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
      |> AddressPage.visit_page(addresses.lincoln)
      |> AddressPage.click_internal_transactions()
      |> AddressPage.apply_filter("To")
      |> assert_has(AddressPage.internal_transactions(count: 1))
    end
  end
end
