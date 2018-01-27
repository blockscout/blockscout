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

  test "views blocks on the home page", %{session: session} do
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
    |> assert_has(css(".block-detail__item", text: "0xMrCoolBlock"))
    |> assert_has(css(".block-detail__item", text: "Heathcliff"))
    |> assert_has(css(".block-detail__item", text: "9999999"))
    |> assert_has(css(".block-detail__item", text: "1 hour ago"))
    |> assert_has(css(".block-detail__item", text: "5030101"))
    |> assert_has(css(".block-detail__item", text: "once upon a nonce"))
    |> assert_has(css(".block-detail__item", text: "1010101"))
  end

  test "views transactions on the home page", %{session: session} do
    transaction_block = insert(:block, timestamp: Timex.now |> Timex.shift(hours: -2))
    insert_list(4, :transaction, block: transaction_block)
    insert(:transaction, hash: "0xSk8", value: 5656)

    session
    |> visit("/en")
    |> assert_has(css(".transactions__title", text: "Transactions"))
    |> assert_has(css(".transactions__column--hash", count: 5))
    |> assert_has(css(".transactions__column--value", count: 5))
    |> assert_has(css(".transactions__column--age", count: 5))

    session
    |> click(link("0xSk8"))
    |> assert_has(css(".transaction-detail__hash", text: "0xSk8"))
    |> assert_has(css(".transaction-detail__item", text: "5656"))
  end
end
