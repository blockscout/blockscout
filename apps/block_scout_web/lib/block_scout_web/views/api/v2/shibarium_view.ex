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
    %{
      items:
        Enum.map(deposits, fn deposit ->
          %{
            "l1_block_number" => deposit.l1_block_number,
            "l1_transaction_hash" => deposit.l1_transaction_hash,
            "l2_transaction_hash" => deposit.l2_transaction_hash,
            "user" => user(deposit.user, conn),
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
    %{
      items:
        Enum.map(withdrawals, fn withdrawal ->
          %{
            "l2_block_number" => withdrawal.l2_block_number,
            "l2_transaction_hash" => withdrawal.l2_transaction_hash,
            "l1_transaction_hash" => withdrawal.l1_transaction_hash,
            "user" => user(withdrawal.user, conn),
            "timestamp" => withdrawal.timestamp
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("shibarium_items_count.json", %{count: count}) do
    count
  end

  defp user(user_address_raw, conn) do
    {user_address, user_address_hash} =
      with false <- is_nil(user_address_raw),
           {:ok, address} <-
             Chain.hash_to_address(
               user_address_raw,
               [necessity_by_association: %{:names => :optional, :smart_contract => :optional}, api?: true],
               false
             ) do
        {address, address.hash}
      else
        _ -> {nil, nil}
      end

    case Helper.address_with_info(conn, user_address, user_address_hash, true) do
      nil -> user_address_raw
      address -> address
    end
  end
end
