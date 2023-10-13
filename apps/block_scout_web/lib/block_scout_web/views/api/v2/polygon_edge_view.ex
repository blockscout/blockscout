defmodule BlockScoutWeb.API.V2.PolygonEdgeView do
  use BlockScoutWeb, :view

  @spec render(String.t(), map()) :: map()
  def render("polygon_edge_deposits.json", %{
        deposits: deposits,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(deposits, fn deposit ->
          %{
            "msg_id" => deposit.msg_id,
            "from" => deposit.from,
            "to" => deposit.to,
            "l1_transaction_hash" => deposit.l1_transaction_hash,
            "l1_timestamp" => deposit.l1_timestamp,
            "success" => deposit.success,
            "l2_transaction_hash" => deposit.l2_transaction_hash
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("polygon_edge_withdrawals.json", %{
        withdrawals: withdrawals,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(withdrawals, fn withdrawal ->
          %{
            "msg_id" => withdrawal.msg_id,
            "from" => withdrawal.from,
            "to" => withdrawal.to,
            "l2_transaction_hash" => withdrawal.l2_transaction_hash,
            "l2_timestamp" => withdrawal.l2_timestamp,
            "success" => withdrawal.success,
            "l1_transaction_hash" => withdrawal.l1_transaction_hash
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("polygon_edge_items_count.json", %{count: count}) do
    count
  end
end
