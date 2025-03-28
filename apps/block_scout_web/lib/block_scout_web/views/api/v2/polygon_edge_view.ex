defmodule BlockScoutWeb.API.V2.PolygonEdgeView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain
  alias Explorer.Chain.PolygonEdge.Reader

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

  def extend_transaction_json_response(out_json, transaction_hash, connection) do
    out_json
    |> Map.put("polygon_edge_deposit", polygon_edge_deposit(transaction_hash, connection))
    |> Map.put("polygon_edge_withdrawal", polygon_edge_withdrawal(transaction_hash, connection))
  end

  defp polygon_edge_deposit(transaction_hash, conn) do
    transaction_hash
    |> Reader.deposit_by_transaction_hash()
    |> polygon_edge_deposit_or_withdrawal(conn)
  end

  defp polygon_edge_withdrawal(transaction_hash, conn) do
    transaction_hash
    |> Reader.withdrawal_by_transaction_hash()
    |> polygon_edge_deposit_or_withdrawal(conn)
  end

  defp polygon_edge_deposit_or_withdrawal(item, conn) do
    if not is_nil(item) do
      {from_address, from_address_hash} = hash_to_address_and_hash(item.from)
      {to_address, to_address_hash} = hash_to_address_and_hash(item.to)

      item
      |> Map.put(:from, Helper.address_with_info(conn, from_address, from_address_hash, item.from))
      |> Map.put(:to, Helper.address_with_info(conn, to_address, to_address_hash, item.to))
    end
  end

  defp hash_to_address_and_hash(hash) do
    with false <- is_nil(hash),
         {:ok, address} <-
           Chain.hash_to_address(
             hash,
             necessity_by_association: %{
               :names => :optional,
               :smart_contract => :optional,
               proxy_implementations_association() => :optional
             },
             api?: true
           ) do
      {address, address.hash}
    else
      _ -> {nil, nil}
    end
  end
end
