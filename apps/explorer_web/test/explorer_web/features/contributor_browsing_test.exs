defmodule ExplorerWeb.ContributorBrowsingTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query, only: [css: 1, css: 2, link: 1]

  alias Explorer.Chain.{Credit, Debit}

  @logo css("[data-test='header_logo']")

  test "browses the home page", %{session: session} do
    session |> visit("/")
    assert current_path(session) == "/en"

    session
    |> click(@logo)
    |> assert_has(css("main", text: "Blocks"))
  end

  test "search for blocks", %{session: session} do
    block = insert(:block, number: 42)

    refute block.miner_hash == nil

    session
    |> visit("/")
    |> fill_in(css(".header__cell--search-input"), with: to_string(block.number))
    |> send_keys([:enter])
    |> assert_has(css(".block__item", text: to_string(block.miner_hash)))
  end

  test "search for transactions", %{session: session} do
    transaction = insert(:transaction, input: "0x736f636b73")

    session
    |> visit("/")
    |> fill_in(
      css(".header__cell--search-input"),
      with: to_string(transaction.hash)
    )
    |> send_keys([:enter])
    |> assert_has(css(".transaction__item", text: to_string(transaction.input)))
  end

  test "search for address", %{session: session} do
    address = insert(:address)

    session
    |> visit("/")
    |> fill_in(
      css(".header__cell--search-input"),
      with: to_string(address.hash)
    )
    |> send_keys([:enter])
    |> assert_has(css(".address__subheading", text: to_string(address.hash)))
  end

  test "views blocks", %{session: session} do
    timestamp = Timex.now() |> Timex.shift(hours: -1)
    Enum.map(307..310, &insert(:block, number: &1, timestamp: timestamp, gas_used: 10))

    fifth_block =
      insert(:block, %{
        gas_limit: 5_030_101,
        gas_used: 1_010_101,
        nonce: 123_456_789,
        number: 311,
        size: 9_999_999,
        timestamp: timestamp
      })

    transaction = insert(:transaction, block_hash: fifth_block.hash, index: 0)

    insert(:transaction, block_hash: fifth_block.hash, index: 1)
    insert(:transaction, block_hash: fifth_block.hash, index: 2)
    insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)

    Credit.refresh()
    Debit.refresh()

    session
    |> visit("/en")
    |> assert_has(css(".blocks__title", text: "Blocks"))
    |> assert_has(css(".blocks__column--height", count: 2, text: "1"))
    |> assert_has(css(".blocks__column--transactions-count", count: 5))
    |> assert_has(css(".blocks__column--transactions-count", count: 1, text: "3"))
    |> assert_has(css(".blocks__column--age", count: 5, text: "1 hour ago"))
    |> assert_has(css(".blocks__column--gas-used", count: 5, text: "10"))

    session
    |> click(link("Blocks"))
    |> assert_has(css(".blocks__column--height", text: "311"))
    |> click(link("311"))
    |> assert_has(css(".block__item", text: to_string(fifth_block.hash)))
    |> assert_has(css(".block__item", text: to_string(fifth_block.miner_hash)))
    |> assert_has(css(".block__item", text: "9,999,999"))
    |> assert_has(css(".block__item", text: "1 hour ago"))
    |> assert_has(css(".block__item", text: "5,030,101"))
    |> assert_has(css(".block__item", text: to_string(fifth_block.nonce)))
    |> assert_has(css(".block__item", text: "1,010,101"))
    |> click(css(".block__link", text: "Transactions"))
    |> assert_has(css(".transactions__link--long-hash", text: to_string(transaction.hash)))
  end

  describe "transactions and address pages" do
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
          value: Explorer.Chain.Wei.from(Decimal.new(5656), :ether),
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

    test "views transactions", %{session: session} do
      session
      |> visit("/en")
      |> assert_has(css(".transactions__title", text: "Transactions"))
      |> assert_has(css(".transactions__column--hash", count: 5))
      |> assert_has(css(".transactions__column--value", count: 5))
      |> assert_has(css(".transactions__column--age", count: 5))
    end

    test "can see pending transactions", %{pending: pending, session: session} do
      session
      |> visit("/transactions")
      |> click(css(".transactions__tab-link", text: "Pending"))
      |> click(css(".transactions__link", text: to_string(pending.hash)))
      |> assert_has(css(".transaction__item-value--status", text: "Pending"))
    end

    test "don't see pending transactions by default", %{session: session} do
      session
      |> visit("/transactions")
      |> refute_has(css(".transactions__column--block", text: "Pending"))
    end

    test "see's all addresses transactions by default", %{
      lincoln: lincoln,
      session: session,
      transaction: transaction,
      txn_from_lincoln: txn_from_lincoln
    } do
      session
      |> visit("/en/addresses/#{Phoenix.Param.to_param(lincoln)}")
      |> assert_has(css(".transactions__link--long-hash", text: to_string(transaction.hash)))
      |> assert_has(css(".transactions__link--long-hash", text: to_string(txn_from_lincoln.hash)))
    end

    test "can filter to only see transactions to an address", %{
      lincoln: lincoln,
      session: session,
      transaction: transaction,
      txn_from_lincoln: txn_from_lincoln
    } do
      session
      |> visit("/en/addresses/#{Phoenix.Param.to_param(lincoln)}")
      |> click(css("[data-test='filter_dropdown']", text: "Filter: All"))
      |> click(css(".address__link", text: "To"))
      |> assert_has(css(".transactions__link--long-hash", text: to_string(transaction.hash)))
      |> refute_has(css(".transactions__link--long-hash", text: to_string(txn_from_lincoln.hash)))
    end

    test "can filter to only see transactions from an address", %{
      lincoln: lincoln,
      session: session,
      transaction: transaction,
      txn_from_lincoln: txn_from_lincoln
    } do
      session
      |> visit("/en/addresses/#{Phoenix.Param.to_param(lincoln)}")
      |> click(css("[data-test='filter_dropdown']", text: "Filter: All"))
      |> click(css(".address__link", text: "From"))
      |> assert_has(css(".transactions__link--long-hash", text: to_string(txn_from_lincoln.hash)))
      |> refute_has(css(".transactions__link--long-hash", text: to_string(transaction.hash)))
    end
  end

  test "views addresses", %{session: session} do
    address = insert(:address, fetched_balance: 500)

    session
    |> visit("/en/addresses/#{Phoenix.Param.to_param(address)}")
    |> assert_has(css(".address__balance", text: "0.000,000,000,000,000,500 POA"))
  end
end
