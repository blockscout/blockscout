defmodule BlockScoutWeb.ViewingTransactionsTest do
  @moduledoc false

  import Mox

  use BlockScoutWeb.FeatureCase, async: false

  alias BlockScoutWeb.{AddressPage, TransactionListPage, TransactionLogsPage, TransactionPage}
  alias Explorer.Chain.Wei

  setup :set_mox_global

  setup do
    block =
      insert(:block, %{
        timestamp: Timex.now() |> Timex.shift(hours: -2),
        gas_used: 123_987
      })

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

    transaction =
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

    insert(:log, address: lincoln, index: 0, transaction: transaction, block: block, block_number: block.number)

    internal =
      insert(:internal_transaction,
        index: 0,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_index: 0
      )

    {:ok,
     %{
       pending: pending,
       pending_contract: pending_contract,
       internal: internal,
       lincoln: lincoln,
       taft: taft,
       transaction: transaction,
       txn_from_lincoln: txn_from_lincoln
     }}
  end

  describe "viewing transaction lists" do
    test "viewing the default transactions tab", %{
      session: session,
      transaction: transaction,
      pending: pending
    } do
      session
      |> TransactionListPage.visit_page()
      |> assert_has(TransactionListPage.transaction(transaction))
      |> assert_has(TransactionListPage.transaction_status(transaction))
      |> refute_has(TransactionListPage.transaction(pending))
    end

    test "viewing the pending transactions list", %{
      pending: pending,
      pending_contract: pending_contract,
      session: session
    } do
      session
      |> TransactionListPage.visit_pending_transactions_page()
      |> assert_has(TransactionListPage.transaction(pending))
      |> assert_has(TransactionListPage.transaction(pending_contract))
      |> assert_has(TransactionListPage.transaction_status(pending_contract))
    end

    test "contract creation is shown for to_address on list page", %{session: session} do
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(to_address: nil)
        |> with_block()
        |> with_contract_creation(contract_address)

      :internal_transaction_create
      |> insert(transaction: transaction, index: 0, block_hash: transaction.block_hash, block_index: 0)
      |> with_contract_creation(contract_address)

      session
      |> TransactionListPage.visit_page()
      |> assert_has(TransactionListPage.contract_creation(transaction))
    end
  end

  describe "viewing a pending transaction page" do
    test "can see a pending transaction's details", %{session: session, pending: pending} do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn %{id: _id, method: "net_version", params: []}, _options ->
        {:ok, "100"}
      end)

      session
      |> TransactionPage.visit_page(pending)
      |> assert_has(TransactionPage.detail_hash(pending))
      |> assert_has(TransactionPage.is_pending())
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
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: false)

      session
      |> TransactionLogsPage.visit_page(transaction)
      |> TransactionLogsPage.click_address(lincoln)
      |> assert_has(AddressPage.detail_hash(lincoln))
    end
  end
end
