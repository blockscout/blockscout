defmodule BlockScoutWeb.ViewingAddressesTest do
  use BlockScoutWeb.FeatureCase, async: true

  alias Explorer.Chain.Wei
  alias BlockScoutWeb.{AddressPage, AddressView, Notifier}

  setup do
    block = insert(:block)

    {:ok, balance} = Wei.cast(5)
    lincoln = insert(:address, fetched_coin_balance: balance)
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

  test "viewing address overview information", %{session: session} do
    address = insert(:address, fetched_coin_balance: 500)

    session
    |> AddressPage.visit_page(address)
    |> assert_text(AddressPage.balance(), "0.0000000000000005 POA")
  end

  describe "viewing contract creator" do
    test "see the contract creator and transaction links", %{session: session} do
      address = insert(:address)
      contract = insert(:contract_address)
      transaction = insert(:transaction, from_address: address, created_contract_address: contract)

      internal_transaction =
        insert(
          :internal_transaction_create,
          index: 0,
          transaction: transaction,
          from_address: address,
          created_contract_address: contract
        )

      address_hash = AddressView.trimmed_hash(address.hash)
      transaction_hash = AddressView.trimmed_hash(transaction.hash)

      session
      |> AddressPage.visit_page(internal_transaction.created_contract_address)
      |> assert_text(AddressPage.contract_creator(), "#{address_hash} at #{transaction_hash}")
    end

    test "see the contract creator and transaction links even when the creator is another contract", %{session: session} do
      lincoln = insert(:address)
      contract = insert(:contract_address)
      transaction = insert(:transaction)
      another_contract = insert(:contract_address)

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

      contract_hash = AddressView.trimmed_hash(contract.hash)
      transaction_hash = AddressView.trimmed_hash(transaction.hash)

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

      contract_address = insert(:contract_address)

      from_lincoln =
        :transaction
        |> insert(from_address: lincoln, to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block(block)

      internal_transaction =
        :internal_transaction_create
        |> insert(
          transaction: from_lincoln,
          from_address: lincoln,
          index: 0
        )
        |> with_contract_creation(contract_address)

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
      |> refute_has(AddressPage.transaction_address_link(transactions.from_lincoln, :from))
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
      |> refute_has(AddressPage.internal_transaction_address_link(internal_transaction, :to))
    end

    test "viewing new internal transactions via live update", %{addresses: addresses, session: session} do
      transaction =
        :transaction
        |> insert(from_address: addresses.lincoln)
        |> with_block()

      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> AddressPage.click_internal_transactions()
      |> assert_has(AddressPage.internal_transactions(count: 2))

      internal_transaction =
        insert(:internal_transaction, transaction: transaction, index: 0, from_address: addresses.lincoln)

      Notifier.handle_event({:chain_event, :internal_transactions, [internal_transaction]})

      session
      |> assert_has(AddressPage.internal_transactions(count: 3))
      |> assert_has(AddressPage.internal_transaction(internal_transaction))
    end
  end

  test "viewing transaction count", %{addresses: addresses, session: session} do
    insert_list(1000, :transaction, to_address: addresses.lincoln)

    session
    |> AddressPage.visit_page(addresses.lincoln)
    |> assert_text(AddressPage.transaction_count(), "1,002")
  end

  test "contract creation is shown for to_address on list page", %{
    addresses: addresses,
    block: block,
    session: session
  } do
    lincoln = addresses.lincoln
    contract_address = insert(:contract_address)

    from_lincoln =
      :transaction
      |> insert(from_address: lincoln, to_address: nil)
      |> with_block(block)
      |> with_contract_creation(contract_address)

    internal_transaction =
      :internal_transaction_create
      |> insert(
        transaction: from_lincoln,
        from_address: lincoln,
        index: 0
      )
      |> with_contract_creation(contract_address)

    session
    |> AddressPage.visit_page(addresses.lincoln)
    |> AddressPage.click_internal_transactions()
    |> assert_has(AddressPage.contract_creation(internal_transaction))
  end

  describe "viewing token transfers" do
    test "contributor can see all token transfers that he sent", %{
      addresses: addresses,
      block: block,
      session: session
    } do
      lincoln = addresses.lincoln
      taft = addresses.taft

      contract_address = insert(:contract_address)
      insert(:token, contract_address: contract_address)

      transaction =
        :transaction
        |> insert(from_address: lincoln, to_address: contract_address)
        |> with_block(block)

      insert(
        :token_transfer,
        from_address: lincoln,
        to_address: taft,
        transaction: transaction,
        token_contract_address: contract_address
      )

      session
      |> AddressPage.visit_page(lincoln)
      |> assert_has(AddressPage.token_transfers(transaction, count: 1))
      |> assert_has(AddressPage.token_transfer(transaction, lincoln, count: 1))
      |> assert_has(AddressPage.token_transfer(transaction, taft, count: 1))
      |> refute_has(AddressPage.token_transfers_expansion(transaction))
    end

    test "contributor can see only token transfers related to him", %{
      addresses: addresses,
      block: block,
      session: session
    } do
      lincoln = addresses.lincoln
      taft = addresses.taft
      morty = build(:address)

      contract_address = insert(:contract_address)
      insert(:token, contract_address: contract_address)

      transaction =
        :transaction
        |> insert(from_address: lincoln, to_address: contract_address)
        |> with_block(block)

      insert(
        :token_transfer,
        from_address: lincoln,
        to_address: taft,
        transaction: transaction,
        token_contract_address: contract_address
      )

      insert(
        :token_transfer,
        from_address: lincoln,
        to_address: morty,
        transaction: transaction,
        token_contract_address: contract_address
      )

      session
      |> AddressPage.visit_page(morty)
      |> assert_has(AddressPage.token_transfers(transaction, count: 1))
      |> assert_has(AddressPage.token_transfer(transaction, lincoln, count: 1))
      |> assert_has(AddressPage.token_transfer(transaction, morty, count: 1))
      |> refute_has(AddressPage.token_transfer(transaction, taft, count: 1))
    end

    test "transactions with multiple token transfers shows only the first one by default", %{
      addresses: addresses,
      block: block,
      session: session
    } do
      lincoln = addresses.lincoln
      taft = addresses.taft

      contract_address = insert(:contract_address)

      insert(:token, contract_address: contract_address)

      transaction =
        :transaction
        |> insert(from_address: lincoln, to_address: contract_address)
        |> with_block(block)

      insert_list(
        3,
        :token_transfer,
        from_address: lincoln,
        to_address: taft,
        transaction: transaction,
        token_contract_address: contract_address
      )

      session
      |> AddressPage.visit_page(lincoln)
      |> assert_has(AddressPage.token_transfers(transaction, count: 1))
    end

    test "transaction with multiple token transfers shows all transfers if expanded", %{
      addresses: addresses,
      block: block,
      session: session
    } do
      lincoln = addresses.lincoln
      taft = addresses.taft

      contract_address = insert(:contract_address)
      insert(:token, contract_address: contract_address)

      transaction =
        :transaction
        |> insert(from_address: lincoln, to_address: contract_address)
        |> with_block(block)

      insert_list(
        3,
        :token_transfer,
        from_address: lincoln,
        to_address: taft,
        transaction: transaction,
        token_contract_address: contract_address
      )

      session
      |> AddressPage.visit_page(lincoln)
      |> click(AddressPage.token_transfers_expansion(transaction))
      |> assert_has(AddressPage.token_transfers(transaction, count: 3))
    end
  end
end
