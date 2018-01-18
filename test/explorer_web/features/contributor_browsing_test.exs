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
    insert_list(5, :block, %{number: 4})
    session
    |> visit("/")
    |> assert_has(css(".blocks__title", text: "Blocks"))
    |> assert_has(css(".blocks__row", count: 5, text: "4"))
  end
end
