defmodule Explorer.Chain.Statistics.ServerTest do
  use Explorer.DataCase

  alias Explorer.Chain.Statistics
  alias Explorer.Chain.Statistics.Server

  describe "init/1" do
    test "returns a new chain when not told to refresh" do
      {:ok, statistics} = Server.init(false)

      assert statistics.number == Statistics.fetch().number
    end

    test "returns a new chain when told to refresh" do
      {:ok, statistics} = Server.init(true)

      assert statistics == Statistics.fetch()
    end

    test "refreshes when told to refresh" do
      {:ok, _} = Server.init(true)

      assert_receive :refresh, 2_000
    end
  end

  describe "handle_info/2" do
    test "returns the original chain when sent a :refresh message" do
      original = Statistics.fetch()

      assert {:noreply, ^original} = Server.handle_info(:refresh, original)
    end

    test "launches an update when sent a :refresh message" do
      original = Statistics.fetch()
      {:ok, pid} = Server.start_link()
      chain = Server.fetch()
      :ok = GenServer.stop(pid)

      assert original.number == chain.number
    end

    test "does not reply when sent any other message" do
      assert {:noreply, _} = Server.handle_info(:ham, %Statistics{})
    end
  end

  describe "handle_call/3" do
    test "replies with statistics when sent a :fetch message" do
      original = Statistics.fetch()

      assert {:reply, _, ^original} = Server.handle_call(:fetch, self(), original)
    end

    test "does not reply when sent any other message" do
      assert {:noreply, _} = Server.handle_call(:ham, self(), %Statistics{})
    end
  end

  describe "handle_cast/2" do
    test "schedules a refresh of the statistics when sent an update" do
      statistics = Statistics.fetch()

      Server.handle_cast({:update, statistics}, %Statistics{})

      assert_receive :refresh, 2_000
    end

    test "returns a noreply and the new incoming chain when sent an update" do
      original = Statistics.fetch()

      assert {:noreply, ^original} = Server.handle_cast({:update, original}, %Statistics{})
    end

    test "returns a noreply and the old chain when sent any other cast" do
      original = Statistics.fetch()

      assert {:noreply, ^original} = Server.handle_cast(:ham, original)
    end
  end
end
