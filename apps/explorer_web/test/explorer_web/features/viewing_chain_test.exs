defmodule ExplorerWeb.ViewingChainTest do
  @moduledoc false

  use ExplorerWeb.FeatureCase, async: true

  alias ExplorerWeb.{AddressPage, BlockPage, ChainPage, Notifier, TransactionPage}

  setup do
    [oldest_block | _] = Enum.map(401..404, &insert(:block, number: &1))

    block = insert(:block, number: 405)

    [oldest_transaction | _] =
      4
      |> insert_list(:transaction)
      |> with_block(block)

    :transaction
    |> insert()
    |> with_block(block)

    {:ok,
     %{
       block: block,
       last_shown_block: oldest_block,
       last_shown_transaction: oldest_transaction
     }}
  end

  describe "statistics" do
    test "average block time live updates", %{session: session} do
      time = DateTime.utc_now()

      for x <- 100..0 do
        insert(:block, timestamp: Timex.shift(time, seconds: -5 * x), number: x + 500)
      end

      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.average_block_time("5 seconds"))

      block =
        100..0
        |> Enum.map(fn index ->
          insert(:block, timestamp: Timex.shift(time, seconds: -10 * index), number: index + 800)
        end)
        |> hd()

      Notifier.handle_event({:chain_event, :blocks, [block]})

      assert_has(session, ChainPage.average_block_time("10 seconds"))
    end

    test "address count live updates", %{session: session} do
      count = ExplorerWeb.FakeAdapter.address_estimated_count()

      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.address_count(count))

      address = insert(:address)
      Notifier.handle_event({:chain_event, :addresses, [address]})

      assert_has(session, ChainPage.address_count(count + 1))
    end
  end

  describe "viewing addresses" do
    test "search for address", %{session: session} do
      address = insert(:address)

      session
      |> ChainPage.visit_page()
      |> ChainPage.search(to_string(address.hash))
      |> assert_has(AddressPage.detail_hash(address))
    end
  end

  describe "viewing blocks" do
    test "search for blocks from chain page", %{session: session} do
      block = insert(:block, number: 6)

      session
      |> ChainPage.visit_page()
      |> ChainPage.search(to_string(block.number))
      |> assert_has(BlockPage.detail_number(block))
    end

    test "blocks list", %{session: session} do
      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.blocks(count: 4))
    end

    test "viewing new blocks via live update", %{session: session, last_shown_block: last_shown_block} do
      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.blocks(count: 4))

      block = insert(:block, number: 6)

      Notifier.handle_event({:chain_event, :blocks, [block]})

      session
      |> assert_has(ChainPage.blocks(count: 4))
      |> assert_has(ChainPage.block(block))
      |> refute_has(ChainPage.block(last_shown_block))
    end
  end

  describe "viewing transactions" do
    test "search for transactions", %{session: session} do
      transaction = insert(:transaction)

      session
      |> ChainPage.visit_page()
      |> ChainPage.search(to_string(transaction.hash))
      |> assert_has(TransactionPage.detail_hash(transaction))
    end

    test "transactions list", %{session: session} do
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

      # internal_transaction =
      #   :internal_transaction_create
      #   |> insert(transaction: transaction, index: 0)
      #   |> with_contract_creation(contract_address)

      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.contract_creation(transaction))
    end
  end
end
