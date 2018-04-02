defmodule ExplorerWeb.JavascriptTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query, only: [css: 1]

  test "runs jasmine", %{session: session} do
    session
    |> visit("/jasmine")
    |> assert_has(css(".jasmine-bar.jasmine-passed"))
  end
end
