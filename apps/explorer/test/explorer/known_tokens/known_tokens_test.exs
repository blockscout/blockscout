defmodule Explorer.KnownTokensTest do
  use ExUnit.Case, async: false

  import Mox

  alias Plug.Conn
  alias Explorer.Chain.Hash
  alias Explorer.KnownTokens
  alias Explorer.KnownTokens.Source.TestSource

  @moduletag :capture_log

  setup :verify_on_exit!

  setup do
    set_mox_global()

    # Use TestSource mock and ets table for this test set
    source_configuration = Application.get_env(:explorer, Explorer.KnownTokens.Source)
    known_tokens_configuration = Application.get_env(:explorer, Explorer.KnownTokens)

    Application.put_env(:explorer, Explorer.KnownTokens.Source, source: TestSource)
    Application.put_env(:explorer, Explorer.KnownTokens, table_name: :known_tokens)
    Application.put_env(:explorer, Explorer.KnownTokens, enabled: true)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.KnownTokens.Source, source_configuration)
      Application.put_env(:explorer, Explorer.KnownTokens, known_tokens_configuration)
    end)
  end

  test "init" do
    assert :ets.info(KnownTokens.table_name()) == :undefined

    assert {:ok, %{}} == KnownTokens.init([])
    assert_received :update
    table = :ets.info(KnownTokens.table_name())
    refute table == :undefined
    assert table[:name] == KnownTokens.table_name()
    assert table[:named_table]
    assert table[:read_concurrency]
    assert table[:type] == :set
    refute table[:write_concurrency]
  end

  test "handle_info with :update" do
    bypass = Bypass.open()

    Bypass.expect(bypass, "GET", "/", fn conn ->
      Conn.resp(conn, 200, ~s([{"symbol": "TEST1","address": "0x0000000000000000000000000000000000000001"}]))
    end)

    stub(TestSource, :source_url, fn -> "http://localhost:#{bypass.port}" end)

    KnownTokens.init([])
    state = %{}

    assert {:noreply, ^state} = KnownTokens.handle_info(:update, state)
    assert_receive {_, {:ok, [%{"symbol" => "TEST1", "address" => "0x0000000000000000000000000000000000000001"}]}}
  end

  describe "ticker fetch task" do
    setup do
      KnownTokens.init([])
      :ok
    end

    test "with successful fetch" do
      symbol = "TEST2"
      address = "0x0000000000000000000000000000000000000002"

      token = %{
        "symbol" => symbol,
        "address" => address
      }

      state = %{}

      assert {:noreply, ^state} = KnownTokens.handle_info({nil, {:ok, [token]}}, state)

      assert [{"TEST2", "0x0000000000000000000000000000000000000002"}] == :ets.lookup(KnownTokens.table_name(), symbol)
    end

    test "with failed fetch" do
      bypass = Bypass.open()

      Bypass.expect(bypass, "GET", "/", fn conn ->
        Conn.resp(conn, 200, "{}")
      end)

      stub(TestSource, :source_url, fn -> "http://localhost:#{bypass.port}" end)

      state = %{}

      assert {:noreply, ^state} = KnownTokens.handle_info({nil, {:error, "some error"}}, state)

      assert_receive {_, {:ok, _}}
    end
  end

  test "list/0" do
    KnownTokens.init([])

    known_tokens = [
      {"TEST1", "0x0000000000000000000000000000000000000001"},
      {"TEST2", "0x0000000000000000000000000000000000000002"}
    ]

    :ets.insert(KnownTokens.table_name(), known_tokens)

    expected_tokens =
      known_tokens
      |> Enum.map(&elem(&1, 1))
      |> Enum.map(&Hash.Address.cast/1)

    assert expected_tokens == KnownTokens.list()
  end

  test "lookup/1" do
    KnownTokens.init([])

    known_tokens = [
      {"TEST1", "0x0000000000000000000000000000000000000001"},
      {"TEST2", "0x0000000000000000000000000000000000000002"}
    ]

    :ets.insert(KnownTokens.table_name(), known_tokens)

    assert Hash.Address.cast("0x0000000000000000000000000000000000000001") == KnownTokens.lookup("TEST1")
    assert nil == KnownTokens.lookup("nope")
  end

  test "lookup when disabled" do
    Application.put_env(:explorer, Explorer.KnownTokens, enabled: false)

    assert nil == KnownTokens.lookup("z")
  end
end
