defmodule ExplorerWeb.ExqTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query, only: [css: 2]

  test "views the exq dashboard", %{session: session} do
    session
    |> visit("/exq")
    |> assert_has(css(".navbar-brand", text: "Exq"))
  end
end
