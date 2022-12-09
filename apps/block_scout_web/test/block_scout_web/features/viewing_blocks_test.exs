defmodule BlockScoutWeb.ViewingBlocksTest do
  use BlockScoutWeb.FeatureCase, async: false

  alias BlockScoutWeb.{BlockListPage, BlockPage}

  alias Explorer.Celo.CacheHelper
  alias Explorer.Chain.Block

  import Mox

  setup :set_mox_global

  setup do
    CacheHelper.set_test_addresses(%{
      "Governance" => "0xD533Ca259b330c7A88f74E000a3FaEa2d63B7972"
    })

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
        |> insert(
          transaction: transaction,
          index: 0,
          block_hash: transaction.block_hash,
          block_index: 1
        )
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
        token_contract_address: contract_token_address,
        block: block
      )

      visited_page_session =
        session
        |> BlockPage.visit_page(block)
        |> BlockPage.accept_cookies_click()

      # token transfers are loaded in defer tags - https://github.com/blockscout/blockscout/pull/4398
      # sleep here to ensure js is loaded before assertion
      Process.sleep(:timer.seconds(1))

      visited_page_session
      |> assert_has(BlockPage.token_transfers(transaction, count: 1))
      |> click(BlockPage.token_transfers_expansion(transaction))
      |> assert_has(BlockPage.token_transfers(transaction, count: 3))
    end

    test "show reorg detail page", %{session: session} do
      reorg = insert(:block, consensus: false)

      session
      |> BlockPage.visit_page(reorg)
      |> assert_has(BlockPage.detail_number(reorg))
      |> assert_has(BlockPage.page_type("Fetching Details"))
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

    test "inserts place holder blocks on render for out of order blocks", %{session: session} do
      insert(:block, number: 315)

      session
      |> BlockListPage.visit_page()
      |> assert_has(BlockListPage.block(%Block{number: 314}))
      |> assert_has(BlockListPage.place_holder_blocks(3))
    end
  end
end
