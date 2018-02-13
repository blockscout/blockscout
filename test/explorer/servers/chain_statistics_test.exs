defmodule Explorer.Servers.ChainStatisticsTest do
  use Explorer.DataCase

  alias Explorer.Chain
  alias Explorer.Servers.ChainStatistics

  describe "init/1" do
    test "returns the chain that was passed in" do
      chain = %Chain{}
      {:ok, statistics} = ChainStatistics.init(chain)
      assert statistics == chain
    end
  end

  describe "refresh/1" do
    test "schedules a refresh of the statistics" do
      ChainStatistics.refresh(0)
      assert_receive :refresh
    end
  end

  describe "handle_info/2" do
    test "fetches statistics when sent a :refresh message" do
      {:noreply, chain} = ChainStatistics.handle_info(:refresh, nil)
      assert chain == Chain.fetch()
    end

    test "does not reply when sent any other message" do
      {status, _} = ChainStatistics.handle_info(:ham, nil)
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
      {status, _} = ChainStatistics.handle_call(:ham, self(), nil)
      assert status == :noreply
    end
  end
end
