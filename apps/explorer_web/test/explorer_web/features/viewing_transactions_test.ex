defmodule ExplorerWeb.ViewingTransactionsTest do
  use ExplorerWeb.FeatureCase, async: true

  alias Explorer.Chain.{Credit, Debit, Wei}
  alias ExplorerWeb.{AddressPage, HomePage, TransactionListPage, TransactionLogsPage, TransactionPage}

  setup do
    block =
      insert(:block, %{
        number: 555,
        timestamp: Timex.now() |> Timex.shift(hours: -2),
        gas_used: 123_987
      })

    for index <- 0..3, do: insert(:transaction, block_hash: block.hash, index: index)
    pending = insert(:transaction, block_hash: nil, gas: 5891, index: nil)

    lincoln = insert(:address)
    taft = insert(:address)

    transaction =
      insert(
        :transaction,
        block_hash: block.hash,
        value: Wei.from(Decimal.new(5656), :ether),
        gas: Decimal.new(1_230_000_000_000_123_123),
        gas_price: Decimal.new(7_890_000_000_898_912_300_045),
        index: 4,
        input: "0x000012",
        nonce: 99045,
        inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
        updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"),
        from_address_hash: taft.hash,
        to_address_hash: lincoln.hash
      )

    receipt = insert(:receipt, status: :ok, transaction_hash: transaction.hash, transaction_index: transaction.index)
    insert(:log, address_hash: lincoln.hash, index: 0, transaction_hash: receipt.transaction_hash)

    # From Lincoln to Taft.
    txn_from_lincoln =
      insert(
        :transaction,
        block_hash: block.hash,
        index: 5,
        from_address_hash: lincoln.hash,
        to_address_hash: taft.hash
      )

    internal_receipt =
      insert(:receipt, transaction_hash: txn_from_lincoln.hash, transaction_index: txn_from_lincoln.index)

    internal = insert(:internal_transaction, transaction_hash: internal_receipt.transaction_hash)

    Credit.refresh()
    Debit.refresh()

    {:ok,
     %{
       pending: pending,
       internal: internal,
       lincoln: lincoln,
       taft: taft,
       transaction: transaction,
       txn_from_lincoln: txn_from_lincoln
     }}
  end

  describe "viewing transaction lists" do
    test "transactions on the home page", %{session: session} do
      session
      |> HomePage.visit_page()
      |> assert_has(HomePage.transactions(count: 5))
    end

    test "viewing the default transactions tab", %{session: session, transaction: transaction, pending: pending} do
      session
      |> TransactionListPage.visit_page()
      |> assert_has(TransactionListPage.transaction(transaction))
      |> refute_has(TransactionListPage.transaction(pending))
    end

    test "viewing the pending tab", %{pending: pending, session: session} do
      session
      |> TransactionListPage.visit_page()
      |> TransactionListPage.click_pending()
      |> assert_has(TransactionListPage.transaction(pending))
      # |> click(css(".transactions__link", text: to_string(pending.hash)))
    end
  end

  describe "viewing a transaction page" do
    test "can navigate to transaction show from list page", %{session: session, transaction: transaction} do
      session
      |> TransactionListPage.visit_page()
      |> TransactionListPage.click_transaction(transaction)
      |> assert_has(TransactionPage.detail_hash(transaction))
    end

    test "can see a transaction's details", %{session: session, transaction: transaction} do
      session
      |> TransactionPage.visit_page(transaction)
      |> assert_has(TransactionPage.detail_hash(transaction))
    end

    test "can view a transaction's logs", %{session: session, transaction: transaction} do
      session
      |> TransactionPage.visit_page(transaction)
      |> TransactionPage.click_logs()
      |> assert_has(TransactionLogsPage.logs(count: 1))
    end

    test "can visit an address from the transaction logs page", %{
      lincoln: lincoln,
      session: session,
      transaction: transaction
    } do
      session
      |> TransactionLogsPage.visit_page(transaction)
      |> TransactionLogsPage.click_address(lincoln)
      |> assert_has(AddressPage.detail_hash(lincoln))
    end
  end
end
