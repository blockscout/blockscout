defmodule Explorer.MicroserviceInterfaces.BENSTest do
  use ExUnit.Case, async: true

  alias Explorer.MicroserviceInterfaces.BENS

  setup do
    old_bens_env = Application.get_env(:explorer, BENS, [])

    on_exit(fn ->
      Application.put_env(:explorer, BENS, old_bens_env)
    end)

    :ok
  end

  describe "maybe_preload_ens_for_blocks/1" do
    test "returns input as-is when blocks BENS preload is disabled" do
      Application.put_env(
        :explorer,
        BENS,
        Keyword.put(Application.get_env(:explorer, BENS, []), :disable_blocks_bens_preload, true)
      )

      blocks = [%{number: 1}, %{number: 2}]

      assert BENS.maybe_preload_ens_for_blocks(blocks) == blocks
    end
  end

  describe "maybe_preload_ens_for_transactions/1" do
    test "returns input as-is when transactions BENS preload is disabled" do
      Application.put_env(
        :explorer,
        BENS,
        Keyword.put(Application.get_env(:explorer, BENS, []), :disable_transactions_bens_preload, true)
      )

      transactions = [%{hash: "0x1"}, %{hash: "0x2"}]

      assert BENS.maybe_preload_ens_for_transactions(transactions) == transactions
    end
  end

  describe "maybe_preload_ens_for_token_transfers/1" do
    test "returns input as-is when token transfers BENS preload is disabled" do
      Application.put_env(
        :explorer,
        BENS,
        Keyword.put(Application.get_env(:explorer, BENS, []), :disable_token_transfers_bens_preload, true)
      )

      token_transfers = [%{token_id: "1"}, %{token_id: "2"}]

      assert BENS.maybe_preload_ens_for_token_transfers(token_transfers) == token_transfers
    end
  end
end
