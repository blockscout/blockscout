defmodule Explorer.Servers.ChainStatisticsTest do
  use Explorer.DataCase

  alias Explorer.Chain
  alias Explorer.Servers.ChainStatistics

  describe "init/1" do
    test "returns a new chain when not told to refresh" do
      {:ok, statistics} = ChainStatistics.init(false)
      assert statistics == Chain.fetch()
    end

    test "returns a new chain when told to refresh" do
      {:ok, statistics} = ChainStatistics.init(true)
      assert statistics == Chain.fetch()
    end

    test "refreshes when told to refresh" do
      {:ok, _} = ChainStatistics.init(true)
      assert_receive :refresh, 2_000
    end
  end

  describe "fetch/0" do
    test "fetches the chain when not started" do
      original = Chain.fetch()
      chain = ChainStatistics.fetch()
      assert chain == original
    end
  end

  describe "handle_info/2" do
    test "returns the original chain when sent a :refresh message" do
      original = Chain.fetch()
      {:noreply, chain} = ChainStatistics.handle_info(:refresh, original)
      assert chain == original
    end

    test "launches an update when sent a :refresh message" do
      original = Chain.fetch()
      {:ok, pid} = Explorer.Servers.ChainStatistics.start_link()
      chain = ChainStatistics.fetch()
      :ok = GenServer.stop(pid)
      assert original.number == chain.number
    end

    test "does not reply when sent any other message" do
      {status, _} = ChainStatistics.handle_info(:ham, %Chain{})
      assert status == :noreply
    end
  end

  describe "handle_call/3" do
    test "replies with statistics when sent a :fetch message" do
      original = Chain.fetch()
      {:reply, _, chain} = ChainStatistics.handle_call(:fetch, self(), original)
      assert chain == original
    end

    test "does not reply when sent any other message" do
      {status, _} = ChainStatistics.handle_call(:ham, self(), %Chain{})
      assert status == :noreply
    end
  end

  describe "handle_cast/2" do
    test "schedules a refresh of the statistics when sent an update" do
      chain = Chain.fetch()
      ChainStatistics.handle_cast({:update, chain}, %Chain{})
      assert_receive :refresh, 2_000
    end

    test "returns a noreply and the new incoming chain when sent an update" do
      original = Chain.fetch()
      {:noreply, chain} = ChainStatistics.handle_cast({:update, original}, %Chain{})
      assert chain == original
    end

    test "returns a noreply and the old chain when sent any other cast" do
      original = Chain.fetch()
      {:noreply, chain} = ChainStatistics.handle_cast(:ham, original)
      assert chain == original
    end
  end
end
