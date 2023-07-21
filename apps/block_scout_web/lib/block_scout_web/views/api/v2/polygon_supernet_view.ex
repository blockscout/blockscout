defmodule BlockScoutWeb.API.V2.PolygonSupernetView do
  use BlockScoutWeb, :view

  def render("polygon_supernet_deposits.json", %{
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

  def render("polygon_supernet_items_count.json", %{count: count}) do
    count
  end
end
