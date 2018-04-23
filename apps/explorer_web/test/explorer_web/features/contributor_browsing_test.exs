defmodule ExplorerWeb.UserListTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query, only: [css: 1, css: 2, link: 1]

  # alias Explorer.Chain
  alias Explorer.Chain.{Address, Block, Credit, Debit, Transaction}

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
    %Block{miner_hash: miner_hash} = insert(:block, number: 42)

    session
    |> visit("/")
    |> fill_in(css(".header__cell--search-input"), with: "42")
    |> send_keys([:enter])
    |> assert_has(css(~s|.block__item dd[title="#{miner_hash}"]|))
  end

  test "search for transactions", %{session: session} do
    input = "INPUT"
    %Transaction{hash: hash} = insert(:transaction, input: input)

    session
    |> visit("/")
    |> fill_in(css(".header__cell--search-input"), with: to_string(hash))
    |> send_keys([:enter])
    |> assert_has(css(".transaction__item", text: input))
  end

  test "search for address", %{session: session} do
    %Address{hash: hash} = insert(:address)
    string = to_string(hash)

    session
    |> visit("/")
    |> fill_in(css(".header__cell--search-input"), with: string)
    |> send_keys([:enter])
    |> assert_has(css(".address__subheading", text: string))
  end

  test "views blocks", %{session: session} do
    insert_list(4, :block, %{
      timestamp: Timex.now() |> Timex.shift(hours: -1),
      gas_used: 10
    })

    number = 311
    number_string = to_string(number)

    fifth_block =
      insert(:block, %{
        number: number,
        timestamp: Timex.now() |> Timex.shift(hours: -1),
        size: 9_999_999,
        nonce: "once upon a nonce",
        gas_used: 1_010_101,
        gas_limit: 5_030_101
      })

    transaction = insert(:transaction, block_hash: fifth_block.hash, index: 0)

    insert(:transaction, block_hash: fifth_block.hash, index: 1)
    insert(:transaction, block_hash: fifth_block.hash, index: 2)
    insert(:receipt, transaction: transaction)

    Credit.refresh()
    Debit.refresh()

    session
    |> visit("/en")
    |> assert_has(css(".blocks__title", text: "Blocks"))
    |> assert_has(css(".blocks__column--transactions-count", count: 5))
    |> assert_has(css(".blocks__column--transactions-count", count: 1, text: "3"))
    |> assert_has(css(".blocks__column--age", count: 5, text: "1 hour ago"))
    |> assert_has(css(".blocks__column--gas-used", count: 5, text: "10"))

    session
    |> click(link("Blocks"))
    |> assert_has(css(".blocks__column--height", text: number_string))
    |> click(link(number_string))
    |> assert_has(css(~s|.block__item dd[title="#{fifth_block.hash}"]|))
    |> assert_has(css(~s|.block__item dd[title="#{fifth_block.miner_hash}"]|))
    |> assert_has(css(".block__item", text: "9,999,999"))
    |> assert_has(css(".block__item", text: "1 hour ago"))
    |> assert_has(css(".block__item", text: "5,030,101"))
    |> assert_has(css(".block__item", text: "once upon a nonce"))
    |> assert_has(css(".block__item", text: "1,010,101"))
    |> click(css(".block__link", text: "Transactions"))
    |> assert_has(css(".transactions__link--long-hash", text: to_string(transaction.hash)))
  end

  test "views transactions", %{session: session} do
    block =
      insert(:block, %{
        number: 555,
        timestamp: Timex.now() |> Timex.shift(hours: -2),
        gas_used: 123_987
      })

    Enum.each(0..3, &insert(:transaction, block_hash: block.hash, index: &1))
    #    pending_transaction = insert(:transaction, gas: 5891)

    lincoln = insert(:address)
    taft = insert(:address)

    transaction =
      insert(
        :transaction,
        block_hash: block.hash,
        from_address_hash: taft.hash,
        gas: Decimal.new(1_230_000_000_000_123_123),
        gas_price: Decimal.new(7_890_000_000_898_912_300_045),
        index: 4,
        input: "0x00012",
        inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
        nonce: 99045,
        to_address_hash: lincoln.hash,
        updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"),
        value: Explorer.Chain.Wei.from(Decimal.new(5656), :ether)
      )

    receipt = insert(:receipt, transaction: transaction, status: 1)
    insert(:log, address_hash: lincoln.hash, receipt: receipt)

    # From Lincoln to Taft.
    transaction_from_lincoln =
      insert(
        :transaction,
        block_hash: block.hash,
        from_address_hash: lincoln.hash,
        index: 5,
        to_address_hash: taft.hash
      )

    insert(:receipt, transaction: transaction_from_lincoln)

    #    internal = insert(:internal_transaction, transaction_hash: transaction.hash)

    Credit.refresh()
    Debit.refresh()

    #    transaction_hash_string = to_string(transaction.hash)

    session
    |> visit("/en")
    |> assert_has(css(".transactions__title", text: "Transactions"))
    |> assert_has(css(".transactions__column--hash", count: 5))
    |> assert_has(css(".transactions__column--value", count: 5))
    |> assert_has(css(".transactions__column--age", count: 5, visible: false))

    #    |> visit("/transactions")
    #    |> click(css(".transactions__tab-link", text: "Pending"))
    #    |> click(css(".transactions__link", text: Chain.transaction_hash_to_string(pending_transaction.hash)))
    #    |> assert_has(css(".transaction__item-value--status", text: "Pending"))
    #    |> visit("/transactions")
    #    |> refute_has(css(".transactions__column--block", text: "Pending"))
    #    |> click(link(transaction_hash_string))
    #    |> assert_has(css(".transaction__subheading", text: transaction_hash_string))
    #    |> assert_has(css(".transaction__item", text: "123,987"))
    #    |> assert_has(css(".transaction__item", text: "5,656 POA"))
    #    |> assert_has(css(".transaction__item", text: "Success"))
    #    |> assert_has(
    #      css(
    #        ".transaction__item",
    #        text: "7,890,000,000,898,912,300,045 Wei (7,890,000,000,898.912 Gwei)"
    #      )
    #    )
    #    |> assert_has(css(".transaction__item", text: "1,230,000,000,000,123,123 Gas"))
    #    |> assert_has(css(".transaction__item", text: "0x00012"))
    #    |> assert_has(css(".transaction__item", text: "99045"))
    #    |> assert_has(css(".transaction__item", text: "123,987"))
    #    |> assert_has(css(".transaction__item", text: "0xlincoln"))
    #    |> assert_has(css(".transaction__item", text: "0xhowardtaft"))
    #    |> assert_has(css(".transaction__item", text: "block confirmations"))
    #    |> assert_has(css(".transaction__item", text: "49 years ago"))
    #    |> assert_has(css(".transaction__item", text: "38 years ago"))
    #    |> click(link("Internal Transactions"))
    #    |> assert_has(css(".internal-transaction__table", text: internal.call_type))
    #    |> visit("/en/transactions/0xSk8")
    #    |> click(link("Logs"))
    #    |> assert_has(css(".transaction-log__link", text: "0xlincoln"))
    #    |> click(css(".transaction-log__link", text: "0xlincoln"))
    #    |> assert_has(css(".address__subheading", text: "0xlincoln"))
    #    |> click(css(".address__link", text: "Transactions To"))
    #    |> assert_has(css(".transactions__link--long-hash", text: "0xSk8"))
    #    |> click(css(".address__link", text: "Transactions From"))
    #    |> assert_has(
    #      css(".transactions__link--long-hash", text: Chain.transaction_hash_to_string(transaction_from_lincoln.hash))
    #    )
  end

  test "views addresses", %{session: session} do
    address = insert(:address, balance: 500)

    session
    |> visit("/en/addresses/#{Phoenix.Param.to_param(address)}")
    |> assert_has(css(".address__balance", text: "0.0000000000000005"))
  end
end
