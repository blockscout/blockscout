# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Accounts.RefresherTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.Accounts
  alias Explorer.Chain.Cache.Accounts.Refresher
  alias Explorer.PagingOptions

  describe "start_link/1" do
    test "fills the cache from the database" do
      hashes = insert_top_addresses(3)

      start_refresher()

      assert cached_hashes() == hashes
    end
  end

  describe "fetch_top_addresses/1" do
    test "runs one query for concurrent misses and serves all of them from it" do
      hashes = insert_top_addresses(3)

      start_refresher()
      empty_cache()
      count_addresses_queries()

      results =
        1..5
        |> Enum.map(fn _ ->
          Task.async(fn -> Address.list_top_addresses(paging_options: %PagingOptions{page_size: 2}) end)
        end)
        |> Task.await_many()

      expected_hashes = Enum.take(hashes, 2)

      assert Enum.all?(results, fn addresses -> Enum.map(addresses, & &1.hash) == expected_hashes end)
      # the refill fills the whole cache, not only the page that missed
      assert cached_hashes() == hashes

      assert_received :addresses_query
      refute_received :addresses_query
    end

    test "shares a failed refill with every concurrent caller instead of retrying it" do
      insert_top_addresses(2)

      start_refresher()
      empty_cache()
      count_addresses_queries()

      # Without the shared sandbox the refill task, which does not run on behalf
      # of the test process, fails to check out a connection. The callers below
      # do run on its behalf, so a retry in a caller would succeed and be counted.
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo, :manual)

      errors =
        1..3
        |> Enum.map(fn _ -> Task.async(fn -> catch_error(Refresher.fetch_top_addresses(2)) end) end)
        |> Task.await_many()

      assert Enum.all?(errors, &match?(%DBConnection.OwnershipError{}, &1))

      # the failed attempt is reported as a query too; a retry in a caller would
      # add a successful one
      assert_received :addresses_query
      refute_received :addresses_query
    end

    test "runs the query in the caller while the refresher is not running" do
      hashes = insert_top_addresses(2)

      assert Address.list_top_addresses() |> Enum.map(& &1.hash) == hashes
      assert cached_hashes() == hashes
    end
  end

  # Balances descend with insertion order, so the returned hashes are in the
  # order the top list reports them.
  defp insert_top_addresses(count) do
    count..1//-1
    |> Enum.map(&insert(:address, fetched_coin_balance: &1))
    |> Enum.map(& &1.hash)
  end

  defp cached_hashes do
    Accounts.all() |> Enum.map(& &1.hash)
  end

  # The process starts a refill on start; a fetch through it is served from that
  # refill, so returning from it means the cache is filled.
  defp start_refresher do
    start_supervised!(Refresher)

    Refresher.fetch_top_addresses(1)
  end

  defp empty_cache do
    Supervisor.terminate_child(Explorer.Supervisor, Accounts.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Accounts.child_id())
  end

  # Sends `:addresses_query` to the test process for every query on the
  # `addresses` table, wherever in the node it runs.
  defp count_addresses_queries do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach(
      handler_id,
      [:explorer, :repo, :query],
      fn _event, _measurements, %{source: source}, _config ->
        if source == "addresses", do: send(test_pid, :addresses_query)
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end
end
