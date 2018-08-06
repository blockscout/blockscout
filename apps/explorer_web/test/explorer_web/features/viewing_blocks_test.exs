defmodule ExplorerWeb.ViewingBlocksTest do
  use ExplorerWeb.FeatureCase, async: true

  alias ExplorerWeb.{BlockListPage, BlockPage, ChainPage, Notifier}

  setup do
    timestamp = Timex.now() |> Timex.shift(hours: -1)
    [oldest_block | _] = Enum.map(308..310, &insert(:block, number: &1, timestamp: timestamp, gas_used: 10))

    newest_block =
      insert(:block, %{
        gas_limit: 5_030_101,
        gas_used: 1_010_101,
        nonce: 123_456_789,
        number: 311,
        size: 9_999_999,
        timestamp: timestamp
      })

    {:ok, first_shown_block: newest_block, last_shown_block: oldest_block}
  end

  test "viewing blocks on the chain page", %{session: session} do
    session
    |> ChainPage.visit_page()
    |> assert_has(ChainPage.blocks(count: 4))
  end

  test "viewing new blocks via live update on chain", %{session: session, last_shown_block: last_shown_block} do
    session
    |> ChainPage.visit_page()
    |> assert_has(ChainPage.blocks(count: 4))

    block = insert(:block, number: 42)

    Notifier.handle_event({:chain_event, :blocks, [block]})

    session
    |> assert_has(ChainPage.blocks(count: 4))
    |> assert_has(ChainPage.block(block))
    |> refute_has(ChainPage.block(last_shown_block))
  end

  test "search for blocks from chain page", %{session: session} do
    block = insert(:block, number: 42)

    session
    |> ChainPage.visit_page()
    |> ChainPage.search(to_string(block.number))
    |> assert_has(BlockPage.detail_number(block))
  end

  test "show block detail page", %{session: session} do
    block = insert(:block, number: 42)

    session
    |> BlockPage.visit_page(block)
    |> assert_has(BlockPage.detail_number(block))
  end

  test "block detail page has transactions", %{session: session} do
    block = insert(:block, number: 42)

    transaction =
      :transaction
      |> insert()
      |> with_block(block)

    session
    |> BlockPage.visit_page(block)
    |> assert_has(BlockPage.detail_number(block))
    |> assert_has(BlockPage.transaction(transaction))
    |> assert_has(BlockPage.transaction_status(transaction))
  end

  test "contract creation is shown for to_address in transaction list", %{session: session} do
    block = insert(:block, number: 42)

    contract_address = insert(:contract_address)

    transaction =
      :transaction
      |> insert(to_address: nil)
      |> with_contract_creation(contract_address)
      |> with_block(block)

    internal_transaction =
      :internal_transaction_create
      |> insert(transaction: transaction, index: 0)
      |> with_contract_creation(contract_address)

    session
    |> BlockPage.visit_page(block)
    |> assert_has(BlockPage.contract_creation(internal_transaction))
  end

  test "viewing the blocks index page", %{first_shown_block: block, session: session} do
    session
    |> BlockListPage.visit_page()
    |> assert_has(BlockListPage.block(block))
  end

  test "viewing new blocks via live update on list page", %{session: session} do
    BlockListPage.visit_page(session)

    block = insert(:block, number: 42)
    Notifier.handle_event({:chain_event, :blocks, [block]})

    assert_has(session, BlockListPage.block(block))
  end
end
