defmodule ExplorerWeb.UserListTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query, only: [css: 1, css: 2, link: 1]

  @logo css("img.header__logo")

  test "browses the home page", %{session: session} do
    session |> visit("/")
    assert current_path(session) == "/en"

    session
    |> assert_has(css(".header__logo"))
    |> click(@logo)
    |> assert_has(css("main", text: "Blocks"))
  end

  test "views blocks", %{session: session} do
    insert_list(4, :block, %{number: 1, timestamp: Timex.now |> Timex.shift(hours: -1), gas_used: 10})
    fifth_block = insert(:block, %{
      number: 311,
      hash: "0xMrCoolBlock",
      timestamp: Timex.now |> Timex.shift(hours: -1),
      miner: "Heathcliff",
      size: 9999999,
      nonce: "once upon a nonce",
      gas_used: 1010101,
      gas_limit: 5030101
    })
    for _ <- 0..2, do: insert(:transaction) |> with_block(fifth_block) |> with_addresses

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
  end

  test "views transactions", %{session: session} do
    block = insert(:block, %{
      number: 555,
      timestamp: Timex.now |> Timex.shift(hours: -2),
      gas_used: 123987,
    })
    for _ <- 0..3, do: insert(:transaction) |> with_block(block) |> with_addresses
    insert(:transaction, hash: "0xC001", gas: 5891) |> with_block |> with_addresses

    to_address = insert(:address, hash: "0xlincoln")
    from_address = insert(:address, hash: "0xhowardtaft")
    transaction = insert(:transaction,
      hash: "0xSk8",
      value: 5656,
      gas: 1230000000000123123,
      gas_price: 7890000000898912300045,
      input: "0x00012",
      nonce: 99045,
      inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
      updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}")
    )
    insert(:block_transaction, block: block, transaction: transaction)
    insert(:from_address, address: from_address, transaction: transaction)
    insert(:to_address, address: to_address, transaction: transaction)
    transaction_receipt = insert(:transaction_receipt, transaction: transaction, status: 0)
    insert(:log, address: to_address, transaction_receipt: transaction_receipt)

    session
    |> visit("/en")
    |> assert_has(css(".transactions__title", text: "Transactions"))
    |> assert_has(css(".transactions__column--hash", count: 5))
    |> assert_has(css(".transactions__column--value", count: 5))
    |> assert_has(css(".transactions__column--age", count: 5))

    |> click(css(".header__link-name--pending-transactions", text: "Pending Transactions"))
    |> assert_has(css(".transactions__column--hash", text: "0xC001"))
    |> assert_has(css(".transactions__column--gas-limit", text: "5,891"))

    |> click(css(".transactions__link", text: "0xC001"))
    |> assert_has(css(".transaction__item-value--status", text: "Pending"))

    |> click(css(".header__link-name--transactions", text: "Transactions"))
    |> refute_has(css(".transactions__column--block", text: "Pending"))

    |> click(link("0xSk8"))
    |> assert_has(css(".transaction__subheading", text: "0xSk8"))
    |> assert_has(css(".transaction__item", text: "123,987"))
    |> assert_has(css(".transaction__item", text: "5656 POA"))
    |> assert_has(css(".transaction__item", text: "Success"))
    |> assert_has(css(".transaction__item", text: "7,890,000,000,898,912,300,045"))
    |> assert_has(css(".transaction__item", text: "1,230,000,000,000,123,123"))
    |> assert_has(css(".transaction__item", text: "0x00012"))
    |> assert_has(css(".transaction__item", text: "99045"))
    |> assert_has(css(".transaction__item", text: "123,987"))
    |> assert_has(css(".transaction__item", text: "0xlincoln"))
    |> assert_has(css(".transaction__item", text: "0xhowardtaft"))
    |> assert_has(css(".transaction__item", text: "block confirmations"))
    |> assert_has(css(".transaction__item", text: "48 years ago"))
    |> assert_has(css(".transaction__item", text: "38 years ago"))

    |> click(link("Logs"))
    |> assert_has(css(".transaction-log__link", text: "0xlincoln"))

    |> click(link("0xlincoln"))
    |> assert_has(css(".address__subheading", text: "0xlincoln"))
  end
end
