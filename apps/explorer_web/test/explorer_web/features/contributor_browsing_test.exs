defmodule ExplorerWeb.UserListTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query, only: [css: 1, css: 2, link: 1]

  alias Explorer.Chain.{Credit, Debit}

  @logo css("img.header__logo")

  test "browses the home page", %{session: session} do
    session |> visit("/")
    assert current_path(session) == "/en"

    session
    |> assert_has(css(".header__logo"))
    |> click(@logo)
    |> assert_has(css("main", text: "Blocks"))
  end

  test "search for blocks", %{session: session} do
    insert(:block, number: 42, miner: "mittens")

    session
    |> visit("/")
    |> fill_in(css(".header__cell--search-input"), with: "42")
    |> send_keys([:enter])
    |> assert_has(css(".block__item", text: "mittens"))
  end

  test "search for transactions", %{session: session} do
    insert(:transaction, hash: "0xdeadbeef000000000000000000000000000000000", input: "socks")

    session
    |> visit("/")
    |> fill_in(
      css(".header__cell--search-input"),
      with: "0xdeadbeef000000000000000000000000000000000"
    )
    |> send_keys([:enter])
    |> assert_has(css(".transaction__item", text: "socks"))
  end

  test "search for address", %{session: session} do
    insert(:address, hash: "0xBAADF00D00000000000000000000000000000000")

    session
    |> visit("/")
    |> fill_in(
      css(".header__cell--search-input"),
      with: "0xBAADF00D00000000000000000000000000000000"
    )
    |> send_keys([:enter])
    |> assert_has(css(".address__subheading", text: "0xBAADF00D00000000000000000000000000000000"))
  end

  test "views blocks", %{session: session} do
    insert_list(4, :block, %{
      number: 1,
      timestamp: Timex.now() |> Timex.shift(hours: -1),
      gas_used: 10
    })

    fifth_block =
      insert(:block, %{
        number: 311,
        hash: "0xMrCoolBlock",
        timestamp: Timex.now() |> Timex.shift(hours: -1),
        miner: "Heathcliff",
        size: 9_999_999,
        nonce: "once upon a nonce",
        gas_used: 1_010_101,
        gas_limit: 5_030_101
      })

    transaction = insert(:transaction, hash: "0xfaschtnacht") |> with_block(fifth_block)

    insert(:transaction, hash: "0xpaczki") |> with_block(fifth_block)
    insert(:transaction) |> with_block(fifth_block)
    insert(:receipt, transaction: transaction)

    Credit.refresh()
    Debit.refresh()

    session
    |> visit("/en")
    |> assert_has(css(".blocks__title", text: "Blocks"))
    |> assert_has(css(".blocks__column--height", count: 5, text: "1"))
    |> assert_has(css(".blocks__column--transactions-count", count: 5))
    |> assert_has(css(".blocks__column--transactions-count", count: 1, text: "3"))
    |> assert_has(css(".blocks__column--age", count: 5, text: "1 hour ago"))
    |> assert_has(css(".blocks__column--gas-used", count: 5, text: "10"))

    session
    |> click(link("Blocks"))
    |> assert_has(css(".blocks__column--height", text: "311"))
    |> click(link("311"))
    |> assert_has(css(".block__item", text: "0xMrCoolBlock"))
    |> assert_has(css(".block__item", text: "Heathcliff"))
    |> assert_has(css(".block__item", text: "9,999,999"))
    |> assert_has(css(".block__item", text: "1 hour ago"))
    |> assert_has(css(".block__item", text: "5,030,101"))
    |> assert_has(css(".block__item", text: "once upon a nonce"))
    |> assert_has(css(".block__item", text: "1,010,101"))
    |> click(css(".block__link", text: "Transactions"))
    |> assert_has(css(".transactions__link--long-hash", text: "0xfaschtnacht"))
  end

  describe "transactions and address pages" do
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

      internal = insert(:internal_transaction, transaction_id: transaction.id)

      Credit.refresh()
      Debit.refresh()

      {:ok, %{internal: internal}}
    end

    test "views transactions", %{session: session} do
      session
      |> visit("/en")
      |> assert_has(css(".transactions__title", text: "Transactions"))
      |> assert_has(css(".transactions__column--hash", count: 5))
      |> assert_has(css(".transactions__column--value", count: 5))
      |> assert_has(css(".transactions__column--age", count: 5, visible: false))
    end

    test "can see pending transactions", %{session: session} do
      session
      |> visit("/transactions")
      |> click(css(".transactions__tab-link", text: "Pending"))
      |> click(css(".transactions__link", text: "0xC001"))
      |> assert_has(css(".transaction__item-value--status", text: "Pending"))
    end

    test "don't see pending transactions by default", %{session: session} do
      session
      |> visit("/transactions")
      |> refute_has(css(".transactions__column--block", text: "Pending"))
    end

    test "can see a transaction's details", %{session: session} do
      session
      |> visit("/transactions")
      |> click(link("0xSk8"))
      |> assert_has(css(".transaction__subheading", text: "0xSk8"))
      |> assert_has(css(".transaction__item", text: "123,987"))
      |> assert_has(css(".transaction__item", text: "5,656 POA"))
      |> assert_has(css(".transaction__item", text: "Success"))
      |> assert_has(
        css(
          ".transaction__item",
          text: "7,890,000,000,898,912,300,045 Wei (7,890,000,000,898.912 Gwei)"
        )
      )
      |> assert_has(css(".transaction__item", text: "1,230,000,000,000,123,123 Gas"))
      |> assert_has(css(".transaction__item", text: "0x00012"))
      |> assert_has(css(".transaction__item", text: "99045"))
      |> assert_has(css(".transaction__item", text: "123,987"))
      |> assert_has(css(".transaction__item", text: "0xlincoln"))
      |> assert_has(css(".transaction__item", text: "0xhowardtaft"))
      |> assert_has(css(".transaction__item", text: "block confirmations"))
      |> assert_has(css(".transaction__item", text: "49 years ago"))
      |> assert_has(css(".transaction__item", text: "38 years ago"))
    end

    test "can see internal transactions for a transaction", %{
      session: session,
      internal: internal
    } do
      session
      |> visit("/en/transactions/0xSk8")
      |> click(link("Internal Transactions"))
      |> assert_has(css(".internal-transaction__table", text: internal.call_type))
    end

    test "can view a transaction's logs", %{session: session} do
      session
      |> visit("/en/transactions/0xSk8")
      |> click(link("Logs"))
      |> assert_has(css(".transaction-log__link", text: "0xlincoln"))
    end

    test "can visit an address from the transaction logs page", %{session: session} do
      session
      |> visit("/en/transactions/0xSk8/logs")
      |> click(css(".transaction-log__link", text: "0xlincoln"))
      |> assert_has(css(".address__subheading", text: "0xlincoln"))
    end

    test "see's all addresses transactions by default", %{session: session} do
      session
      |> visit("/en/addresses/0xlincoln")
      |> assert_has(css(".transactions__link--long-hash", text: "0xSk8"))
      |> assert_has(css(".transactions__link--long-hash", text: "0xrazerscooter"))
    end

    test "can filter to only see transactions to an address", %{session: session} do
      session
      |> visit("/en/addresses/0xlincoln")
      |> click(css("[data-test='filterDropdown']", text: "Filter: All"))
      |> click(css(".address__link", text: "To"))
      |> assert_has(css(".transactions__link--long-hash", text: "0xSk8"))
      |> refute_has(css(".transactions__link--long-hash", text: "0xrazerscooter"))
    end

    test "can filter to only see transactions from an address", %{session: session} do
      session
      |> visit("/en/addresses/0xlincoln")
      |> click(css("[data-test='filterDropdown']", text: "Filter: All"))
      |> click(css(".address__link", text: "From"))
      |> assert_has(css(".transactions__link--long-hash", text: "0xrazerscooter"))
      |> refute_has(css(".transactions__link--long-hash", text: "0xSk8"))
    end
  end

  test "views addresses", %{session: session} do
    insert(:address, hash: "0xthinmints", balance: 500)

    session
    |> visit("/en/addresses/0xthinmints")
    |> assert_has(css(".address__balance", text: "0.000,000,000,000,000,500 POA"))
  end
end
