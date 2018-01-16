defmodule ExplorerWeb.UserListTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query, only: [css: 2]

  test "browses the home page", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css(".header__title", text: "POA Network Explorer"))
  end
end
