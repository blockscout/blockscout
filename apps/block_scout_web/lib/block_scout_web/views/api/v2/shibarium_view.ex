defmodule BlockScoutWeb.API.V2.ShibariumView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain

  @spec render(String.t(), map()) :: map()
  def render("shibarium_deposits.json", %{
        deposits: deposits,
        next_page_params: next_page_params,
        conn: conn
      }) do
    user_addresses = get_user_addresses(deposits, conn)

    %{
      items:
        Enum.map(deposits, fn deposit ->
          %{
            "l1_block_number" => deposit.l1_block_number,
            "l1_transaction_hash" => deposit.l1_transaction_hash,
            "l2_transaction_hash" => deposit.l2_transaction_hash,
            "user" => Map.get(user_addresses, deposit.user, deposit.user),
            "timestamp" => deposit.timestamp
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("shibarium_withdrawals.json", %{
        withdrawals: withdrawals,
        next_page_params: next_page_params,
        conn: conn
      }) do
    user_addresses = get_user_addresses(withdrawals, conn)

    %{
      items:
        Enum.map(withdrawals, fn withdrawal ->
          %{
            "l2_block_number" => withdrawal.l2_block_number,
            "l2_transaction_hash" => withdrawal.l2_transaction_hash,
            "l1_transaction_hash" => withdrawal.l1_transaction_hash,
            "user" => Map.get(user_addresses, withdrawal.user, withdrawal.user),
            "timestamp" => withdrawal.timestamp
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("shibarium_items_count.json", %{count: count}) do
    count
  end

  defp get_user_addresses(items, conn) do
    items
    |> Enum.map(& &1.user)
    |> Enum.reject(&is_nil(&1))
    |> Enum.uniq()
    |> Chain.hashes_to_addresses(
      necessity_by_association: %{
        :names => :optional,
        :smart_contract => :optional,
        proxy_implementations_association() => :optional
      },
      api?: true
    )
    |> Enum.into(%{}, &{&1.hash, Helper.address_with_info(conn, &1, &1.hash, true)})
  end
end
