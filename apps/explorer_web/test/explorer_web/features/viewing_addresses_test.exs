defmodule ExplorerWeb.ViewingAddressesTest do
  use ExplorerWeb.FeatureCase, async: true

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Wei}
  alias ExplorerWeb.{AddressPage, HomePage, Notifier}

  setup do
    block = insert(:block)

    {:ok, balance} = Wei.cast(5)
    lincoln = insert(:address, fetched_balance: balance)
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

  describe "viewing contract creator" do
    test "see the contract creator and transaction links", %{session: session} do
      address = insert(:address)
      transaction = insert(:transaction, from_address: address)
      contract = insert(:address, contract_code: Explorer.Factory.data("contract_code"))

      internal_transaction =
        insert(
          :internal_transaction_create,
          index: 0,
          transaction: transaction,
          from_address: address,
          created_contract_address: contract
        )

      address_hash = ExplorerWeb.AddressView.trimmed_hash(address.hash)
      transaction_hash = ExplorerWeb.AddressView.trimmed_hash(transaction.hash)

      session
      |> AddressPage.visit_page(internal_transaction.created_contract_address)
      |> assert_text(AddressPage.contract_creator(), "#{address_hash} at #{transaction_hash}")
    end

    test "see the contract creator and transaction links even when the creator is another contract", %{session: session} do
      lincoln = insert(:address)
      contract = insert(:address, contract_code: Explorer.Factory.data("contract_code"))
      transaction = insert(:transaction)
      another_contract = insert(:address, contract_code: Explorer.Factory.data("contract_code"))

      insert(
        :internal_transaction,
        index: 0,
        transaction: transaction,
        from_address: lincoln,
        to_address: contract,
        created_contract_address: contract,
        type: :call
      )

      internal_transaction =
        insert(
          :internal_transaction_create,
          index: 1,
          transaction: transaction,
          from_address: contract,
          created_contract_address: another_contract
        )

      contract_hash = ExplorerWeb.AddressView.trimmed_hash(contract.hash)
      transaction_hash = ExplorerWeb.AddressView.trimmed_hash(transaction.hash)

      session
      |> AddressPage.visit_page(internal_transaction.created_contract_address)
      |> assert_text(AddressPage.contract_creator(), "#{contract_hash} at #{transaction_hash}")
    end
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
      |> assert_has(AddressPage.transaction_status(transactions.from_lincoln))
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

    test "only addresses not matching the page are links", %{
      addresses: addresses,
      session: session,
      transactions: transactions
    } do
      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> assert_has(AddressPage.transaction_address_link(transactions.from_lincoln, :to))
    end
  end

  describe "viewing internal transactions" do
    setup %{addresses: addresses, transactions: transactions} do
      address = addresses.lincoln
      transaction = transactions.from_lincoln

      internal_transaction_lincoln_to_address =
        insert(:internal_transaction, transaction: transaction, to_address: address, index: 0)

      insert(:internal_transaction, transaction: transaction, from_address: address, index: 1)
      {:ok, %{internal_transaction_lincoln_to_address: internal_transaction_lincoln_to_address}}
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

    test "only addresses not matching the page are links", %{
      addresses: addresses,
      internal_transaction_lincoln_to_address: internal_transaction,
      session: session
    } do
      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> AddressPage.click_internal_transactions()
      |> assert_has(AddressPage.internal_transaction_address_link(internal_transaction, :from))
    end
  end

  test "viewing transaction count", %{addresses: addresses, session: session} do
    insert_list(1000, :transaction, to_address: addresses.lincoln)

    session
    |> AddressPage.visit_page(addresses.lincoln)
    |> assert_text(AddressPage.transaction_count(), "1,002")
  end

  test "viewing new transactions via live update", %{addresses: addresses, session: session} do
    transaction =
      :transaction
      |> insert(from_address: addresses.lincoln)
      |> with_block()

    session
    |> AddressPage.visit_page(addresses.lincoln)
    |> assert_has(AddressPage.balance())

    Notifier.handle_event({:chain_event, :transactions, [transaction.hash]})

    assert_has(session, AddressPage.transaction(transaction))
  end

  test "transaction count live updates", %{addresses: addresses, session: session} do
    session
    |> AddressPage.visit_page(addresses.lincoln)
    |> assert_text(AddressPage.transaction_count(), "2")

    transaction =
      :transaction
      |> insert(from_address: addresses.lincoln)
      |> with_block()

    Notifier.handle_event({:chain_event, :transactions, [transaction.hash]})

    assert_text(session, AddressPage.transaction_count(), "3")
  end

  test "viewing updated balance via live update", %{session: session} do
    address = %Address{hash: hash} = insert(:address, fetched_balance: 500)

    session
    |> AddressPage.visit_page(address)
    |> assert_text(AddressPage.balance(), "0.0000000000000005 POA")

    {:ok, [^hash]} =
      Chain.update_balances([
        %{
          fetched_balance: 100,
          fetched_balance_block_number: 1,
          hash: hash
        }
      ])

    {:ok, updated_address} = Chain.hash_to_address(hash)

    Notifier.handle_event({:chain_event, :balance_updates, [updated_address.hash]})

    assert_text(session, AddressPage.balance(), "0.0000000000000001 POA")
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
    |> AddressPage.click_internal_transactions()
    |> assert_has(AddressPage.contract_creation(internal_transaction))
  end
end
