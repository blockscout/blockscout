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
    insert_list(5, :block, %{number: 4, gas_used: 10, timestamp: Timex.now |> Timex.shift(hours: -1)})

    session
    |> visit("/en")
    |> assert_has(css(".blocks__title", text: "Blocks"))
    |> assert_has(css(".blocks__column--height", count: 5, text: "4"))
    |> assert_has(css(".blocks__column--age", count: 5, text: "1 hour ago"))
    |> assert_has(css(".blocks__column--gas-used", count: 5, text: "10"))
  end
end
