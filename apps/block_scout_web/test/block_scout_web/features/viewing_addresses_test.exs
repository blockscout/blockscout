defmodule BlockScoutWeb.ViewingAddressesTest do
  use BlockScoutWeb.FeatureCase,
    # Because ETS tables is shared for `Explorer.Counters.*`
    async: false

  alias Explorer.Counters.AddressesCounter
  alias BlockScoutWeb.{AddressPage, AddressView, Notifier}

  setup do
    Application.put_env(:block_scout_web, :checksum_address_hashes, false)

    block = insert(:block, number: 42)

    lincoln = insert(:address, fetched_coin_balance: 5)
    taft = insert(:address, fetched_coin_balance: 5)

    from_taft =
      :transaction
      |> insert(from_address: taft, to_address: lincoln)
      |> with_block(block)

    from_lincoln =
      :transaction
      |> insert(from_address: lincoln, to_address: taft)
      |> with_block(block)

    lincoln_reward =
      :reward
      |> insert(
        address_hash: lincoln.hash,
        block_hash: block.hash,
        address_type: :emission_funds
      )

    taft_reward =
      :reward
      |> insert(
        address_hash: taft.hash,
        block_hash: block.hash,
        address_type: :validator
      )

    on_exit(fn ->
      Application.put_env(:block_scout_web, :checksum_address_hashes, true)
    end)

    {:ok,
     %{
       addresses: %{lincoln: lincoln, taft: taft},
       block: block,
       rewards: {lincoln_reward, taft_reward},
       transactions: %{from_lincoln: from_lincoln, from_taft: from_taft}
     }}
  end

  describe "viewing top addresses" do
    setup do
      addresses = Enum.map(150..101, &insert(:address, fetched_coin_balance: &1))

      {:ok, %{addresses: addresses}}
    end

    test "lists top addresses", %{session: session, addresses: addresses} do
      [first_address | _] = addresses
      [last_address | _] = Enum.reverse(addresses)

      start_supervised!(AddressesCounter)
      AddressesCounter.consolidate()

      session
      |> AddressPage.visit_page()
      |> assert_has(AddressPage.address(first_address))
      |> assert_has(AddressPage.address(last_address))
    end
  end

  test "viewing address overview information", %{session: session} do
    address = insert(:address, fetched_coin_balance: 500)

    session
    |> AddressPage.visit_page(address)
    |> assert_text(AddressPage.balance(), "0.0000000000000005 CELO")
  end

  describe "viewing contract creator" do
    test "see the contract creator and transaction links", %{session: session} do
      address = insert(:address)
      contract = insert(:contract_address)
      transaction = insert(:transaction, from_address: address, created_contract_address: contract) |> with_block()

      internal_transaction =
        insert(
          :internal_transaction_create,
          index: 1,
          transaction: transaction,
          from_address: address,
          created_contract_address: contract,
          block_hash: transaction.block_hash,
          block_index: 1
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
      transaction = insert(:transaction) |> with_block()
      another_contract = insert(:contract_address)

      insert(
        :internal_transaction,
        index: 1,
        transaction: transaction,
        from_address: lincoln,
        to_address: contract,
        created_contract_address: contract,
        type: :call,
        block_hash: transaction.block_hash,
        block_index: 1
      )

      internal_transaction =
        insert(
          :internal_transaction_create,
          index: 2,
          transaction: transaction,
          from_address: contract,
          created_contract_address: another_contract,
          block_hash: transaction.block_hash,
          block_index: 2
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

    test "sees rewards to and from an address alongside transactions", %{
      addresses: addresses,
      session: session,
      transactions: transactions
    } do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: true)

      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> assert_has(AddressPage.transaction(transactions.from_taft))
      |> assert_has(AddressPage.transaction(transactions.from_lincoln))

      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: false)
    end
  end

  describe "viewing internal transactions" do
    setup %{addresses: addresses, transactions: transactions} do
      address = addresses.lincoln
      transaction = transactions.from_lincoln

      internal_transaction_lincoln_to_address =
        insert(:internal_transaction,
          transaction: transaction,
          to_address: address,
          index: 1,
          block_number: 7000,
          transaction_index: 1,
          block_hash: transaction.block_hash,
          block_index: 1
        )

      insert(:internal_transaction,
        transaction: transaction,
        from_address: address,
        index: 2,
        block_number: 8000,
        transaction_index: 2,
        block_hash: transaction.block_hash,
        block_index: 2
      )

      {:ok, %{internal_transaction_lincoln_to_address: internal_transaction_lincoln_to_address}}
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
        |> with_block(insert(:block, number: 7000))

      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> AddressPage.click_internal_transactions()
      |> assert_has(AddressPage.internal_transactions(count: 2))

      internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          index: 2,
          from_address: addresses.lincoln,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 2
        )

      Notifier.handle_event({:chain_event, :internal_transactions, :realtime, [internal_transaction]})

      session
      |> assert_has(AddressPage.internal_transactions(count: 3))
      |> assert_has(AddressPage.internal_transaction(internal_transaction))
    end

    test "can filter to see internal transactions from an address only", %{
      addresses: addresses,
      session: session
    } do
      block = insert(:block, number: 7000)

      from_lincoln =
        :transaction
        |> insert(from_address: addresses.lincoln)
        |> with_block(block)

      from_taft =
        :transaction
        |> insert(from_address: addresses.taft)
        |> with_block(block)

      insert(:internal_transaction,
        transaction: from_lincoln,
        index: 2,
        from_address: addresses.lincoln,
        block_number: from_lincoln.block_number,
        transaction_index: from_lincoln.index,
        block_hash: from_lincoln.block_hash,
        block_index: 2
      )

      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> AddressPage.apply_filter("From")
      |> assert_has(AddressPage.transaction(from_lincoln))
      |> refute_has(AddressPage.transaction(from_taft))
    end

    test "can filter to see internal transactions to an address only", %{
      addresses: addresses,
      session: session
    } do
      block = insert(:block, number: 7000)

      from_lincoln =
        :transaction
        |> insert(to_address: addresses.lincoln)
        |> with_block(block)

      from_taft =
        :transaction
        |> insert(to_address: addresses.taft)
        |> with_block(block)

      insert(:internal_transaction,
        transaction: from_lincoln,
        index: 2,
        from_address: addresses.lincoln,
        block_number: from_lincoln.block_number,
        transaction_index: from_lincoln.index,
        block_hash: from_lincoln.block_hash,
        block_index: 2
      )

      session
      |> AddressPage.visit_page(addresses.lincoln)
      |> AddressPage.apply_filter("To")
      |> assert_has(AddressPage.transaction(from_lincoln))
      |> refute_has(AddressPage.transaction(from_taft))
    end
  end

  describe "viewing token transfers from a specific token" do
    @tag :skip
    test "list token transfers related to the address", %{
      addresses: addresses,
      block: block,
      session: session
    } do
      lincoln = addresses.lincoln
      taft = addresses.taft

      contract_address = insert(:contract_address)
      token = insert(:token, contract_address: contract_address)

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

      insert(:address_current_token_balance, address: lincoln, token_contract_address_hash: contract_address.hash)

      session
      |> AddressPage.visit_page(lincoln)
      |> AddressPage.click_tokens()
      |> AddressPage.click_token_transfers(token)
      |> assert_has(AddressPage.token_transfers(transaction, count: 1))
      |> assert_has(AddressPage.token_transfer(transaction, lincoln, count: 1))
      |> assert_has(AddressPage.token_transfer(transaction, taft, count: 1))
      |> refute_has(AddressPage.token_transfers_expansion(transaction))
    end
  end

  describe "viewing token balances" do
    setup do
      block = insert(:block)
      lincoln = insert(:address, fetched_coin_balance: 5, fetched_coin_balance_block_number: block.number)
      taft = insert(:address, fetched_coin_balance: 5)

      contract_address = insert(:contract_address)
      insert(:token, name: "atoken", symbol: "AT", contract_address: contract_address, type: "ERC-721")

      transaction =
        :transaction
        |> insert(from_address: lincoln, to_address: contract_address)
        |> with_block(block)

      insert(
        :token_transfer,
        from_address: lincoln,
        to_address: taft,
        block: transaction.block,
        transaction: transaction,
        token_contract_address: contract_address
      )

      insert(:address_current_token_balance,
        address: lincoln,
        token_contract_address_hash: contract_address.hash,
        token_type: "ERC-721"
      )

      contract_address_2 = insert(:contract_address)
      insert(:token, name: "token2", symbol: "T2", contract_address: contract_address_2, type: "ERC-20")

      transaction_2 =
        :transaction
        |> insert(from_address: lincoln, to_address: contract_address_2)
        |> with_block(block)

      insert(
        :token_transfer,
        from_address: lincoln,
        to_address: taft,
        block: block,
        transaction: transaction_2,
        token_contract_address: contract_address_2
      )

      insert(:address_current_token_balance,
        address: lincoln,
        token_contract_address_hash: contract_address_2.hash,
        token_type: "ERC-20"
      )

      {:ok, lincoln: lincoln}
    end

    test "filter tokens balances by token name", %{session: session, lincoln: lincoln} do
      next =
        session
        |> AddressPage.visit_page(lincoln)

      Process.sleep(2_000)

      next
      |> AddressPage.click_balance_dropdown_toggle()
      |> AddressPage.fill_balance_dropdown_search("ato")
      |> assert_has(AddressPage.token_balance(count: 1))
      |> assert_has(AddressPage.token_type(count: 1))
      |> assert_has(AddressPage.token_type_count(type: "ERC-721", text: "1"))
    end

    test "filter token balances by token symbol", %{session: session, lincoln: lincoln} do
      next =
        session
        |> AddressPage.visit_page(lincoln)

      Process.sleep(2_000)

      next
      |> AddressPage.click_balance_dropdown_toggle()
      |> AddressPage.fill_balance_dropdown_search("T2")
      |> assert_has(AddressPage.token_balance(count: 1))
      |> assert_has(AddressPage.token_type(count: 1))
      |> assert_has(AddressPage.token_type_count(type: "ERC-20", text: "1"))
    end

    test "reset token balances filter when dropdown closes", %{session: session, lincoln: lincoln} do
      next =
        session
        |> AddressPage.visit_page(lincoln)

      Process.sleep(2_000)

      next
      |> AddressPage.click_balance_dropdown_toggle()
      |> AddressPage.fill_balance_dropdown_search("ato")
      |> AddressPage.click_outside_of_the_dropdown()
      |> assert_has(AddressPage.token_balance_counter("2"))
    end
  end

  describe "viewing coin balance history" do
    setup do
      address = insert(:address, fetched_coin_balance: 5)
      noon = Timex.now() |> Timex.beginning_of_day() |> Timex.set(hour: 12)
      block = insert(:block, timestamp: noon)
      block_one_day_ago = insert(:block, timestamp: Timex.shift(noon, days: -1))
      insert(:fetched_balance, address_hash: address.hash, value: 5, block_number: block.number)
      insert(:fetched_balance, address_hash: address.hash, value: 10, block_number: block_one_day_ago.number)

      {:ok, address: address}
    end

    @tag :skip
    test "see list of coin balances", %{session: session, address: address} do
      session
      |> AddressPage.visit_page(address)
      |> AddressPage.click_coin_balance_history()
      |> assert_has(AddressPage.coin_balances(count: 2))
    end
  end
end
