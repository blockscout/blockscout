defmodule BlockScoutWeb.AddressControllerTest do
  use BlockScoutWeb.ConnCase,
    # ETS tables are shared in `Explorer.Counters.*`
    async: false

  import Mox

  alias Explorer.Chain.Address
  alias Explorer.Counters.{AddressesCounter, AddressTransactionsCounter}

  describe "GET index/2" do
    setup :set_mox_global

    setup do
      # Use TestSource mock for this test set
      configuration = Application.get_env(:block_scout_web, :show_percentage)
      Application.put_env(:block_scout_web, :show_percentage, false)

      :ok

      on_exit(fn ->
        Application.put_env(:block_scout_web, :show_percentage, configuration)
      end)
    end

    test "returns top addresses", %{conn: conn} do
      address_hashes =
        4..1
        |> Enum.map(&insert(:address, fetched_coin_balance: &1))
        |> Enum.map(& &1.hash)

      start_supervised!(AddressesCounter)
      AddressesCounter.consolidate()

      conn = get(conn, address_path(conn, :index, %{type: "JSON"}))
      {:ok, %{"items" => items}} = Poison.decode(conn.resp_body)

      assert Enum.count(items) == Enum.count(address_hashes)
    end

    test "returns an address's primary name when present", %{conn: conn} do
      address = insert(:address, fetched_coin_balance: 1)
      insert(:address_name, address: address, primary: true, name: "POA Wallet")

      start_supervised!(AddressesCounter)
      AddressesCounter.consolidate()

      conn = get(conn, address_path(conn, :index, %{type: "JSON"}))

      {:ok, %{"items" => [item]}} = Poison.decode(conn.resp_body)

      assert String.contains?(item, "POA Wallet")
    end
  end

  describe "GET show/3" do
    setup :set_mox_global

    setup do
      configuration = Application.get_env(:explorer, :checksum_function)
      Application.put_env(:explorer, :checksum_function, :eth)

      :ok

      on_exit(fn ->
        Application.put_env(:explorer, :checksum_function, configuration)
      end)
    end

    test "redirects to address/:address_id/transactions", %{conn: conn} do
      insert(:address, hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")

      conn = get(conn, "/address/0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")

      assert redirected_to(conn) =~ "/address/0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed/transactions"
    end
  end

  describe "GET address-counters/2" do
    test "returns address counters", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, "/address-counters", %{"id" => Address.checksum(address.hash)})

      assert conn.status == 200
      {:ok, response} = Jason.decode(conn.resp_body)

      assert %{"transaction_count" => 0, "validation_count" => 0} == response
    end
  end
end
