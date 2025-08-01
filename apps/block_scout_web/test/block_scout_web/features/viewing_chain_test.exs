defmodule BlockScoutWeb.ViewingChainTest do
  @moduledoc false

  use BlockScoutWeb.FeatureCase,
    # MUST Be false because ETS tables for Counters are shared
    async: false

  alias BlockScoutWeb.{AddressPage, BlockPage, ChainPage, TransactionPage}
  alias Explorer.Chain.Block
  alias Explorer.Chain.Cache.Counters.AddressesCount

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())

    Enum.map(401..404, &insert(:block, number: &1))

    block = insert(:block, number: 405)

    4
    |> insert_list(:transaction)
    |> with_block(block)

    :transaction
    |> insert()
    |> with_block(block)

    {:ok,
     %{
       block: block
     }}
  end

  describe "viewing addresses" do
    test "search for address", %{session: session} do
      address = insert(:address)

      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      session
      |> ChainPage.visit_page()
      |> ChainPage.search(to_string(address.hash))
      |> assert_has(AddressPage.detail_hash(address))
    end
  end

  describe "viewing blocks" do
    test "search for blocks from chain page", %{session: session} do
      block = insert(:block, number: 6)

      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      session
      |> ChainPage.visit_page()
      |> ChainPage.search(to_string(block.number))
      |> assert_has(BlockPage.detail_number(block))
    end

    test "blocks list", %{session: session} do
      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.blocks(count: 4))
    end

    test "inserts place holder blocks on render for out of order blocks", %{session: session} do
      insert(:block, number: 409)

      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.block(%Block{number: 408}))
      |> assert_has(ChainPage.place_holder_blocks(3))
    end
  end

  describe "viewing transactions" do
    test "search for transactions", %{session: session} do
      block = insert(:block)

      transaction =
        insert(:transaction)
        |> with_block(block)

      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      session
      |> ChainPage.visit_page()
      |> ChainPage.search(to_string(transaction.hash))
      |> assert_has(TransactionPage.detail_hash(transaction))
    end

    test "transactions list", %{session: session} do
      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.transactions(count: 5))
    end

    test "contract creation is shown for to_address", %{session: session, block: block} do
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block(block)

      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.contract_creation(transaction))
    end

    test "transaction with multiple token transfers shows all transfers if expanded", %{
      block: block,
      session: session
    } do
      contract_token_address = insert(:contract_address)
      insert(:token, contract_address: contract_token_address)

      transaction =
        :transaction
        |> insert(to_address: contract_token_address)
        |> with_block(block, status: :ok)

      insert_list(
        3,
        :token_transfer,
        transaction: transaction,
        token_contract_address: contract_token_address,
        block: block
      )

      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      ChainPage.visit_page(session)

      # wait for the `transactions-list` to load
      :timer.sleep(1000)

      session
      |> assert_has(ChainPage.token_transfers(transaction, count: 1))
      |> click(ChainPage.token_transfers_expansion(transaction))
      |> assert_has(ChainPage.token_transfers(transaction, count: 3))
    end
  end
end
