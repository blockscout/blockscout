defmodule ExplorerWeb.ViewingBlocksTest do
  use ExplorerWeb.FeatureCase, async: true

  alias ExplorerWeb.{BlockListPage, BlockPage, HomePage}

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
    |> assert_has(HomePage.blocks(count: 4))
  end

  test "search for blocks from home page", %{session: session} do
    block = insert(:block, number: 42)

    session
    |> HomePage.visit_page()
    |> HomePage.search(to_string(block.number))
    |> assert_has(BlockPage.detail_number(block))
  end

  test "show block detail page", %{session: session} do
    block = insert(:block, number: 42)

    session
    |> BlockPage.visit_page(block)
    |> assert_has(BlockPage.detail_number(block))
  end

  test "contract creation is shown for to_address in transaction list", %{session: session} do
    block = insert(:block, number: 42)

    transaction =
      :transaction
      |> insert(to_address: nil, to_address: nil)
      |> with_block(block)

    internal_transaction = insert(:internal_transaction_create, transaction: transaction, index: 0)

    session
    |> BlockPage.visit_page(block)
    |> assert_has(BlockPage.contract_creation(internal_transaction))
  end

  test "viewing the blocks index page", %{block: block, session: session} do
    session
    |> BlockListPage.visit_page()
    |> assert_has(BlockListPage.block(block))
  end
end
