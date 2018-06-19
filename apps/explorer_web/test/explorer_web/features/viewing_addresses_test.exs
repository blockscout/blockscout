defmodule ExplorerWeb.ViewingAddressesTest do
  use ExplorerWeb.FeatureCase, async: true

  alias ExplorerWeb.{AddressPage, HomePage}

  setup do
    block = insert(:block)

    lincoln = insert(:address)
    taft = insert(:address)

    from_taft =
      :transaction
      |> insert(from_address: taft, to_address: lincoln)
      |> with_block(block)

    from_lincoln =
      :transaction
      |> insert(from_address: lincoln, to_address: taft)
      |> with_block(block)

    {:ok,
     %{
       addresses: %{lincoln: lincoln, taft: taft},
       block: block,
       transactions: %{from_lincoln: from_lincoln, from_taft: from_taft}
     }}
  end

  test "search for address", %{session: session} do
    address = insert(:address)

    session
    |> HomePage.visit_page()
    |> HomePage.search(to_string(address.hash))
    |> assert_has(AddressPage.detail_hash(address))
  end

  test "viewing address overview information", %{session: session} do
    address = insert(:address, fetched_balance: 500)

    session
    |> AddressPage.visit_page(address)
    |> assert_text(AddressPage.balance(), "0.0000000000000005 POA")
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

    test "contract creation is shown for to_address on list page", %{
      addresses: addresses,
      block: block,
      session: session
    } do
      lincoln = addresses.lincoln

      from_lincoln =
        :transaction
        |> insert(from_address: lincoln, to_address: nil)
        |> with_block(block)

      internal_transaction =
        insert(
          :internal_transaction_create,
          transaction: from_lincoln,
          from_address: lincoln,
          index: 0
        )

      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> assert_has(AddressPage.contract_creation(internal_transaction))
    end
  end

  describe "viewing internal transactions" do
    setup %{addresses: addresses, transactions: transactions} do
      address = addresses.lincoln
      transaction = transactions.from_lincoln
      insert(:internal_transaction, transaction: transaction, to_address: address, index: 0)
      insert(:internal_transaction, transaction: transaction, from_address: address, index: 1)
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

  test "viewing transaction count", %{addresses: addresses, session: session} do
    insert_list(1000, :transaction, to_address: addresses.lincoln)

    session
    |> AddressPage.visit_page(addresses.lincoln)
    |> assert_text(AddressPage.transaction_count(), "1,002")
  end

  test "viewing new transactions via live update", %{addresses: addresses, session: session} do
    session =
      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> assert_has(AddressPage.balance())

    transaction =
      :transaction
      |> insert(from_address: addresses.lincoln)
      |> with_block()
      |> Repo.preload([:block, :from_address, :to_address])

    ExplorerWeb.Endpoint.broadcast!("addresses:#{addresses.lincoln.hash}", "transaction", %{transaction: transaction})

    session
    |> assert_has(AddressPage.transaction(transaction))
  end
end
