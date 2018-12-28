defmodule BlockScoutWeb.ViewingAppTest do
  @moduledoc false

  use BlockScoutWeb.FeatureCase, async: true

  alias BlockScoutWeb.AppPage
  alias BlockScoutWeb.Counters.BlocksIndexedCounter
  alias Explorer.Counters.AddressesWithBalanceCounter

  setup do
    start_supervised!(AddressesWithBalanceCounter)
    AddressesWithBalanceCounter.consolidate()

    :ok
  end

  describe "loading bar when indexing" do
    test "shows blocks indexed percentage", %{session: session} do
      for index <- 5..9 do
        insert(:block, number: index)
      end

      assert Explorer.Chain.indexed_ratio() == 0.5

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("50% Blocks Indexed"))
    end

    test "shows tokens loading", %{session: session} do
      for index <- 0..9 do
        insert(:block, number: index)
      end

      assert Explorer.Chain.indexed_ratio() == 1.0

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("Indexing Tokens"))
    end

    test "updates blocks indexed percentage", %{session: session} do
      for index <- 5..9 do
        insert(:block, number: index)
      end

      BlocksIndexedCounter.calculate_blocks_indexed()

      assert Explorer.Chain.indexed_ratio() == 0.5

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("50% Blocks Indexed"))

      insert(:block, number: 4)

      BlocksIndexedCounter.calculate_blocks_indexed()

      assert_has(session, AppPage.indexed_status("60% Blocks Indexed"))
    end

    test "updates when blocks are fully indexed", %{session: session} do
      for index <- 1..9 do
        insert(:block, number: index)
      end

      BlocksIndexedCounter.calculate_blocks_indexed()

      assert Explorer.Chain.indexed_ratio() == 0.9

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

      BlocksIndexedCounter.calculate_blocks_indexed()

      assert Explorer.Chain.indexed_ratio() == 1.0

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("Indexing Tokens"))

      :transaction
      |> insert()
      |> with_block(block, internal_transactions_indexed_at: DateTime.utc_now())

      BlocksIndexedCounter.calculate_blocks_indexed()

      refute_has(session, AppPage.still_indexing?())
    end
  end
end
