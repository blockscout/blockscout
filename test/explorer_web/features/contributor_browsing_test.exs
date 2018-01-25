defmodule ExplorerWeb.UserListTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query, only: [css: 1, css: 2]

  @logo css("img.header__logo")

  test "browses the home page", %{session: session} do
    session |> visit("/")
    assert current_path(session) == "/en"

    session
    |> assert_has(css(".header__title", text: "POA Network Explorer"))
    |> click(@logo)
    |> assert_has(css("main", text: "Welcome to our blockchain explorer."))
  end

  test "views blocks on the home page", %{session: session} do
    insert_list(4, :block, %{number: 1, timestamp: Timex.now |> Timex.shift(hours: -1), gas_used: 10})
    fifth_block = insert(:block, %{number: 1, timestamp: Timex.now |> Timex.shift(hours: -1), gas_used: 10})
    insert_list(3, :transaction, block: fifth_block)

    session
    |> visit("/en")
    |> assert_has(css(".blocks__title", text: "Blocks"))
    |> assert_has(css(".blocks__column--height", count: 5, text: "1"))
    |> assert_has(css(".blocks__column--transactions_count", count: 5))
    |> assert_has(css(".blocks__column--transactions_count", count: 1, text: "3"))
    |> assert_has(css(".blocks__column--age", count: 5, text: "1 hour ago"))
    |> assert_has(css(".blocks__column--gas-used", count: 5, text: "10"))
  end

  test "views transactions on the home page", %{session: session} do
    transaction_block = insert(:block, timestamp: Timex.now |> Timex.shift(hours: -2))
    insert_list(5, :transaction, block: transaction_block)

    session
    |> visit("/en")
    |> assert_has(css(".transactions__title", text: "Transactions"))
    |> assert_has(css(".transactions__column--hash", count: 5))
    |> assert_has(css(".transactions__column--value", count: 5))
    |> assert_has(css(".transactions__column--age", count: 5, text: "2 hours ago"))
  end
end
