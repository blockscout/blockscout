defmodule BlockScoutWeb.ViewingAppTest do
  @moduledoc false

  use BlockScoutWeb.FeatureCase, async: true

  alias BlockScoutWeb.AppPage
  alias BlockScoutWeb.Counters.BlocksIndexedCounter
  alias Explorer.Counters.AddressesCounter
  alias Explorer.{Repo}
  alias Explorer.Chain.{Transaction}

  setup do
    start_supervised!(AddressesCounter)
    AddressesCounter.consolidate()

    :ok
  end

  describe "loading bar when indexing" do
    test "shows blocks indexed percentage", %{session: session} do
      [block | _] =
        for index <- 5..9 do
          insert(:block, number: index)
        end

      :transaction
      |> insert()
      |> with_block(block)

      assert Decimal.cmp(Explorer.Chain.indexed_ratio(), Decimal.from_float(0.5)) == :eq

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("50% Blocks Indexed"))
    end

    test "shows tokens loading", %{session: session} do
      [block | _] =
        for index <- 0..9 do
          insert(:block, number: index)
        end

      :transaction
      |> insert()
      |> with_block(block)

      assert Decimal.cmp(Explorer.Chain.indexed_ratio(), 1) == :eq

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("Indexing Tokens"))
    end

    test "updates blocks indexed percentage", %{session: session} do
      [block | _] =
        for index <- 5..9 do
          insert(:block, number: index)
        end

      :transaction
      |> insert()
      |> with_block(block)

      BlocksIndexedCounter.calculate_blocks_indexed()

      assert Decimal.cmp(Explorer.Chain.indexed_ratio(), Decimal.from_float(0.5)) == :eq

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("50% Blocks Indexed"))

      insert(:block, number: 4)

      BlocksIndexedCounter.calculate_blocks_indexed()

      assert_has(session, AppPage.indexed_status("60% Blocks Indexed"))
    end

    test "updates when blocks are fully indexed", %{session: session} do
      [block | _] =
        for index <- 1..9 do
          insert(:block, number: index)
        end

      :transaction
      |> insert()
      |> with_block(block)

      BlocksIndexedCounter.calculate_blocks_indexed()

      assert Decimal.cmp(Explorer.Chain.indexed_ratio(), Decimal.from_float(0.9)) == :eq

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("90% Blocks Indexed"))

      insert(:block, number: 0)

      BlocksIndexedCounter.calculate_blocks_indexed()

      assert_has(session, AppPage.indexed_status("Indexing Tokens"))
    end

    test "removes message when chain is indexed", %{session: session} do
      [block | _] =
        for index <- 0..9 do
          insert(:block, number: index)
        end

      :transaction
      |> insert()
      |> with_block(block)

      BlocksIndexedCounter.calculate_blocks_indexed()

      assert Decimal.cmp(Explorer.Chain.indexed_ratio(), 1) == :eq

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("Indexing Tokens"))

      Repo.update_all(Transaction, set: [internal_transactions_indexed_at: DateTime.utc_now()])

      BlocksIndexedCounter.calculate_blocks_indexed()

      refute_has(session, AppPage.still_indexing?())
    end
  end
end
