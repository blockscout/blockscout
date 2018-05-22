defmodule ExplorerWeb.ViewingBlocksTest do
  use ExplorerWeb.FeatureCase, async: true

  alias ExplorerWeb.{BlockListPage, HomePage}

  setup do
    timestamp = Timex.now() |> Timex.shift(hours: -1)
    Enum.map(307..310, &insert(:block, number: &1, timestamp: timestamp, gas_used: 10))

    block =
      insert(:block, %{
            gas_limit: 5_030_101,
            gas_used: 1_010_101,
            nonce: 123_456_789,
            number: 311,
            size: 9_999_999,
            timestamp: timestamp
             })

    {:ok, block: block}
  end

  test "viewing blocks on the home page", %{session: session} do
    session
    |> HomePage.visit_page()
    |> assert_has(HomePage.blocks(count: 5))
  end

  test "viewing the blocks index page", %{block: block, session: session} do
    session
    |> BlockListPage.visit_page()
    |> assert_has(BlockListPage.block(block))
  end
end
