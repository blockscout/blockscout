defmodule ExplorerWeb.ViewingTransactionsTest do
  @moduledoc false

  use ExplorerWeb.FeatureCase, async: true

  alias Explorer.Chain.Wei
  alias ExplorerWeb.{AddressPage, HomePage, Notifier, TransactionListPage, TransactionLogsPage, TransactionPage}

  setup do
    block =
      insert(:block, %{
        number: 555,
        timestamp: Timex.now() |> Timex.shift(hours: -2),
        gas_used: 123_987
      })

    [oldest_transaction | _] =
      3
      |> insert_list(:transaction)
      |> with_block()

    pending = insert(:transaction, block_hash: nil, gas: 5891, index: nil)
    pending_contract = insert(:transaction, to_address: nil, block_hash: nil, gas: 5891, index: nil)

    lincoln = insert(:address)
    taft = insert(:address)

    # From Lincoln to Taft.
    txn_from_lincoln =
      :transaction
      |> insert(from_address: lincoln, to_address: taft)
      |> with_block(block)

    newest_transaction =
      :transaction
      |> insert(
        value: Wei.from(Decimal.new(5656), :ether),
        gas: Decimal.new(1_230_000_000_000_123_123),
        gas_price: Decimal.new(7_890_000_000_898_912_300_045),
        input: "0x000012",
        nonce: 99045,
        inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
        updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"),
        from_address: taft,
        to_address: lincoln
      )
      |> with_block(block, gas_used: Decimal.new(1_230_000_000_000_123_000), status: :ok)

    insert(:log, address: lincoln, index: 0, transaction: newest_transaction)

    internal = insert(:internal_transaction, index: 0, transaction: newest_transaction)

    {:ok,
     %{
       pending: pending,
       pending_contract: pending_contract,
       internal: internal,
       lincoln: lincoln,
       taft: taft,
       first_shown_transaction: newest_transaction,
       last_shown_transaction: oldest_transaction,
       txn_from_lincoln: txn_from_lincoln
     }}
  end

  test "search for transactions", %{session: session} do
    transaction = insert(:transaction, input: "0x736f636b73")

    session
    |> HomePage.visit_page()
    |> HomePage.search(to_string(transaction.hash))
    |> assert_has(TransactionPage.detail_hash(transaction))
  end

  describe "viewing transaction lists" do
    test "transactions on the homepage", %{session: session} do
      session
      |> HomePage.visit_page()
      |> assert_has(HomePage.transactions(count: 5))
    end

    test "viewing new transactions via live update on the homepage", %{
      session: session,
      last_shown_transaction: last_shown_transaction
    } do
      session
      |> HomePage.visit_page()
      |> assert_has(HomePage.transactions(count: 5))

      transaction =
        :transaction
        |> insert()
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, [transaction.hash]})

      session
      |> assert_has(HomePage.transactions(count: 5))
      |> assert_has(HomePage.transaction(transaction))
      |> refute_has(HomePage.transaction(last_shown_transaction))
    end

    test "count of non-loaded transactions on homepage live update when batch overflow", %{session: session} do
      transaction_hashes =
        30
        |> insert_list(:transaction)
        |> with_block()
        |> Enum.map(& &1.hash)

      session
      |> HomePage.visit_page()
      |> assert_has(HomePage.transactions(count: 5))

      Notifier.handle_event({:chain_event, :transactions, transaction_hashes})

      assert_has(session, AddressPage.non_loaded_transaction_count("30"))
    end

    test "contract creation is shown for to_address on home page", %{session: session} do
      transaction =
        :transaction
        |> insert(to_address: nil)
        |> with_block()

      internal_transaction = insert(:internal_transaction_create, transaction: transaction, index: 0)

      session
      |> HomePage.visit_page()
      |> assert_has(HomePage.contract_creation(internal_transaction))
    end

    test "viewing the default transactions tab", %{
      session: session,
      first_shown_transaction: transaction,
      pending: pending
    } do
      session
      |> TransactionListPage.visit_page()
      |> assert_has(TransactionListPage.transaction(transaction))
      |> assert_has(TransactionListPage.transaction_status(transaction))
      |> refute_has(TransactionListPage.transaction(pending))
    end

    test "viewing the pending tab", %{pending: pending, pending_contract: pending_contract, session: session} do
      session
      |> TransactionListPage.visit_page()
      |> TransactionListPage.click_pending()
      |> assert_has(TransactionListPage.transaction(pending))
      |> assert_has(TransactionListPage.transaction(pending_contract))
      |> assert_has(TransactionListPage.transaction_status(pending_contract))
    end

    test "contract creation is shown for to_address on list page", %{session: session} do
      transaction =
        :transaction
        |> insert(to_address: nil)
        |> with_block()

      insert(:internal_transaction_create, transaction: transaction, index: 0)

      session
      |> TransactionListPage.visit_page()
      |> assert_has(TransactionListPage.contract_creation(transaction))
    end

    test "viewing new transactions via live update on list page", %{session: session} do
      TransactionListPage.visit_page(session)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, [transaction.hash]})

      assert_has(session, TransactionListPage.transaction(transaction))
    end

    test "count of non-loaded transactions on list page live update when batch overflow", %{session: session} do
      transaction_hashes =
        30
        |> insert_list(:transaction)
        |> with_block()
        |> Enum.map(& &1.hash)

      TransactionListPage.visit_page(session)

      Notifier.handle_event({:chain_event, :transactions, transaction_hashes})

      assert_has(session, TransactionListPage.non_loaded_transaction_count("30"))
    end
  end

  describe "viewing a transaction page" do
    test "can navigate to transaction show from list page", %{session: session, first_shown_transaction: transaction} do
      session
      |> TransactionListPage.visit_page()
      |> TransactionListPage.click_transaction(transaction)
      |> assert_has(TransactionPage.detail_hash(transaction))
    end

    test "can see a transaction's details", %{session: session, first_shown_transaction: transaction} do
      session
      |> TransactionPage.visit_page(transaction)
      |> assert_has(TransactionPage.detail_hash(transaction))
    end

    test "can view a transaction's logs", %{session: session, first_shown_transaction: transaction} do
      session
      |> TransactionPage.visit_page(transaction)
      |> TransactionPage.click_logs()
      |> assert_has(TransactionLogsPage.logs(count: 1))
    end

    test "can visit an address from the transaction logs page", %{
      lincoln: lincoln,
      session: session,
      first_shown_transaction: transaction
    } do
      session
      |> TransactionLogsPage.visit_page(transaction)
      |> TransactionLogsPage.click_address(lincoln)
      |> assert_has(AddressPage.detail_hash(lincoln))
    end

    test "block confirmations via live update", %{session: session, first_shown_transaction: transaction} do
      blocks = [insert(:block, number: transaction.block_number + 10)]

      TransactionPage.visit_page(session, transaction)

      assert_text(session, TransactionPage.block_confirmations(), "0")

      Notifier.handle_event({:chain_event, :blocks, blocks})
      assert_text(session, TransactionPage.block_confirmations(), "10")
    end
  end
end
