# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Accounts.RefresherTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.Accounts
  alias Explorer.Chain.Cache.Accounts.Refresher
  alias Explorer.PagingOptions

  describe "refresh/0" do
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
      assert cached_hashes() == expected_hashes

      assert_received :addresses_query
      refute_received :addresses_query
    end

    test "shares a failed refill with every concurrent caller instead of retrying it" do
      insert_top_addresses(2)

      start_refresher()
      empty_cache()
      count_addresses_queries()

      # an unknown sort column fails inside the database, after the query was issued
      options = [paging_options: %PagingOptions{page_size: 2}, sorting: [asc: :no_such_column]]

      errors =
        1..3
        |> Enum.map(fn _ -> Task.async(fn -> catch_error(Refresher.fetch_top_addresses(options)) end) end)
        |> Task.await_many()

      assert Enum.all?(errors, &match?(%Postgrex.Error{postgres: %{code: :undefined_column}}, &1))

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

  # The process refills the cache on start; `refresh/0` is handled after that
  # first refill, so returning from it means the cache is filled.
  defp start_refresher do
    start_supervised!(Refresher)

    :ok = Refresher.refresh()
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
