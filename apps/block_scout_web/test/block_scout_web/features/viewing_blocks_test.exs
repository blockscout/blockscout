defmodule BlockScoutWeb.ViewingBlocksTest do
  use BlockScoutWeb.FeatureCase, async: true

  alias BlockScoutWeb.{BlockListPage, BlockPage, Notifier}
  alias Explorer.Chain.Block

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

  describe "block details page" do
    test "show block detail page", %{session: session} do
      block = insert(:block, number: 42)

      session
      |> BlockPage.visit_page(block)
      |> assert_has(BlockPage.detail_number(block))
      |> assert_has(BlockPage.page_type("Block Details"))
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

    test "transaction with multiple token transfers shows all transfers if expanded", %{
      first_shown_block: block,
      session: session
    } do
      contract_token_address = insert(:contract_address)
      insert(:token, contract_address: contract_token_address)

      transaction =
        :transaction
        |> insert(to_address: contract_token_address)
        |> with_block(block)

      insert_list(
        3,
        :token_transfer,
        transaction: transaction,
        token_contract_address: contract_token_address
      )

      session
      |> BlockPage.visit_page(block)
      |> assert_has(BlockPage.token_transfers(transaction, count: 1))
      |> click(BlockPage.token_transfers_expansion(transaction))
      |> assert_has(BlockPage.token_transfers(transaction, count: 3))
    end

    test "show reorg detail page", %{session: session} do
      reorg = insert(:block, consensus: false)

      session
      |> BlockPage.visit_page(reorg)
      |> assert_has(BlockPage.detail_number(reorg))
      |> assert_has(BlockPage.page_type("Reorg Details"))
    end

    test "show uncle detail page", %{session: session} do
      uncle = insert(:block, consensus: false)
      insert(:block_second_degree_relation, uncle_hash: uncle.hash)

      session
      |> BlockPage.visit_page(uncle)
      |> assert_has(BlockPage.detail_number(uncle))
      |> assert_has(BlockPage.page_type("Uncle Details"))
    end

    test "show link to uncle on block detail page", %{session: session} do
      block = insert(:block)
      uncle = insert(:block, consensus: false)
      insert(:block_second_degree_relation, uncle_hash: uncle.hash, nephew: block)

      session
      |> BlockPage.visit_page(block)
      |> assert_has(BlockPage.detail_number(block))
      |> assert_has(BlockPage.page_type("Block Details"))
      |> assert_has(BlockPage.uncle_link(uncle))
    end
  end

  describe "viewing blocks list" do
    test "viewing the blocks index page", %{first_shown_block: block, session: session} do
      session
      |> BlockListPage.visit_page()
      |> assert_has(BlockListPage.block(block))
    end

    test "inserts place holder blocks if out of order block received", %{session: session} do
      BlockListPage.visit_page(session)

      block = insert(:block, number: 315)
      Notifier.handle_event({:chain_event, :blocks, :realtime, [block]})

      session
      |> assert_has(BlockListPage.block(block))
      |> assert_has(BlockListPage.place_holder_blocks(3))
    end

    test "replaces place holder block if skipped block received", %{session: session} do
      BlockListPage.visit_page(session)

      block = insert(:block, number: 315)
      Notifier.handle_event({:chain_event, :blocks, :realtime, [block]})

      session
      |> assert_has(BlockListPage.block(block))
      |> assert_has(BlockListPage.place_holder_blocks(3))

      skipped_block = insert(:block, number: 314)
      Notifier.handle_event({:chain_event, :blocks, :realtime, [skipped_block]})

      session
      |> assert_has(BlockListPage.block(skipped_block))
      |> assert_has(BlockListPage.place_holder_blocks(2))
    end

    test "inserts place holder blocks on render for out of order blocks", %{session: session} do
      insert(:block, number: 315)

      session
      |> BlockListPage.visit_page()
      |> assert_has(BlockListPage.block(%Block{number: 314}))
      |> assert_has(BlockListPage.place_holder_blocks(3))
    end

    test "replaces rendered place holder block if skipped block received", %{session: session} do
      insert(:block, number: 315)

      BlockListPage.visit_page(session)

      block = insert(:block, number: 314)
      Notifier.handle_event({:chain_event, :blocks, [block]})

      session
      |> assert_has(BlockListPage.block(block))
      |> assert_has(BlockListPage.place_holder_blocks(2))
    end
  end

  describe "viewing uncle blocks list" do
    setup do
      uncles =
        for _index <- 1..10 do
          uncle = insert(:block, consensus: false)
          insert(:block_second_degree_relation, uncle_hash: uncle.hash)

          :transaction
          |> insert()
          |> with_block(uncle)

          uncle
        end

      {:ok, %{uncles: uncles}}
    end

    test "lists uncle blocks", %{session: session, uncles: [uncle | _]} do
      session
      |> BlockListPage.visit_uncles_page()
      |> assert_has(BlockListPage.block(uncle))
      |> assert_has(BlockListPage.blocks(10))
    end
  end

  describe "viewing reorg blocks list" do
    test "lists uncle blocks", %{session: session} do
      [reorg | _] = insert_list(10, :block, consensus: false)

      session
      |> BlockListPage.visit_reorgs_page()
      |> assert_has(BlockListPage.block(reorg))
      |> assert_has(BlockListPage.blocks(10))
    end
  end
end
