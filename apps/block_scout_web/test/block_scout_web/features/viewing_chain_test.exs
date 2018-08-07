defmodule BlockScoutWeb.ViewingChainTest do
  @moduledoc false

  use BlockScoutWeb.FeatureCase, async: true

  alias BlockScoutWeb.{AddressPage, BlockPage, ChainPage, TransactionPage}

  setup do
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

      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.contract_creation(transaction))
    end
  end
end
