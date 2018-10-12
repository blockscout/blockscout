defmodule BlockScoutWeb.ViewingAppTest do
  @moduledoc false

  use BlockScoutWeb.FeatureCase, async: true

  alias BlockScoutWeb.{AppPage, Notifier}

  describe "loading bar when indexing" do
    test "shows blocks indexed percentage", %{session: session} do
      for index <- 6..10 do
        insert(:block, number: index)
      end

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("50% Blocks Indexed"))
    end

    test "shows tokens loading", %{session: session} do
      for index <- 1..10 do
        insert(:block, number: index)
      end

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("Indexing Tokens"))
    end

    test "live updates blocks indexed percentage", %{session: session} do
      for index <- 6..10 do
        insert(:block, number: index)
      end

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("50% Blocks Indexed"))

      insert(:block, number: 5)
      Notifier.handle_event({:chain_event, :blocks, :catchup, []})

      assert_has(session, AppPage.indexed_status("60% Blocks Indexed"))
    end

    test "live updates when blocks are fully indexed", %{session: session} do
      for index <- 2..10 do
        insert(:block, number: index)
      end

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("90% Blocks Indexed"))

      insert(:block, number: 1)
      Notifier.handle_event({:chain_event, :blocks, :catchup, []})

      assert_has(session, AppPage.indexed_status("Indexing Tokens"))
    end

    test "live removes message when chain is indexed", %{session: session} do
      [block | _] =
        for index <- 1..10 do
          insert(:block, number: index)
        end

      session
      |> AppPage.visit_page()
      |> assert_has(AppPage.indexed_status("Indexing Tokens"))

      :transaction
      |> insert()
      |> with_block(block, internal_transactions_indexed_at: DateTime.utc_now())

      Notifier.handle_event({:chain_event, :blocks, :catchup, []})

      refute_has(session, AppPage.still_indexing?())
    end
  end
end
