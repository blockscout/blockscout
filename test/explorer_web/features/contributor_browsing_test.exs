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
    fifth_block = insert(:block, %{number: 311, hash: "0xMrCoolBlock", timestamp: Timex.now |> Timex.shift(hours: -1), miner: "Heathcliff", size: 9999999, nonce: "once upon a nonce", gas_used: 1010101, gas_limit: 5030101})
    insert_list(3, :transaction, block: fifth_block)

    session
    |> visit("/en")
    |> assert_has(css(".blocks__title", text: "Blocks"))
    |> assert_has(css(".blocks__column--height", count: 5, text: "1"))
    |> assert_has(css(".blocks__column--transactions-count", count: 5))
    |> assert_has(css(".blocks__column--transactions-count", count: 1, text: "3"))
    |> assert_has(css(".blocks__column--age", count: 5, text: "1 hour ago"))
    |> assert_has(css(".blocks__column--gas-used", count: 5, text: "10"))

    session
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
    transaction_block = insert(:block, %{
      timestamp: Timex.now |> Timex.shift(hours: -2),
      gas_used: 123987,
    })
    insert_list(4, :transaction, block: transaction_block)
    insert(:transaction, %{
      hash: "0xSk8",
      value: 5656,
      gas: 12345,
      gas_price: 54321,
      input: "0x00012",
      nonce: 99045,
      block: transaction_block,
    })

    session
    |> visit("/en")
    |> assert_has(css(".transactions__title", text: "Transactions"))
    |> assert_has(css(".transactions__column--hash", count: 5))
    |> assert_has(css(".transactions__column--value", count: 5))
    |> assert_has(css(".transactions__column--age", count: 5))

    session
    |> click(link("0xSk8"))
    |> assert_has(css(".transaction__subheading", text: "0xSk8"))
    |> assert_has(css(".transaction__item", text: "5656 POA"))
    |> assert_has(css(".transaction__item", text: "12,345 wei"))
    |> assert_has(css(".transaction__item", text: "54321 POA"))
    |> assert_has(css(".transaction__item", text: "0x00012"))
    |> assert_has(css(".transaction__item", text: "99045"))
    |> assert_has(css(".transaction__item", text: "123,987 wei"))
  end
end
