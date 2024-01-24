defmodule BlockScoutWeb.API.V2.ShibariumView do
  use BlockScoutWeb, :view

  @spec render(String.t(), map()) :: map()
  def render("shibarium_deposits.json", %{
        deposits: deposits,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(deposits, fn deposit ->
          %{
            "l1_block_number" => deposit.l1_block_number,
            "l1_transaction_hash" => deposit.l1_transaction_hash,
            "l2_transaction_hash" => deposit.l2_transaction_hash,
            "user" => deposit.user,
            "timestamp" => deposit.timestamp
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("shibarium_withdrawals.json", %{
        withdrawals: withdrawals,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(withdrawals, fn withdrawal ->
          %{
            "l2_block_number" => withdrawal.l2_block_number,
            "l2_transaction_hash" => withdrawal.l2_transaction_hash,
            "l1_transaction_hash" => withdrawal.l1_transaction_hash,
            "user" => withdrawal.user,
            "timestamp" => withdrawal.timestamp
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("shibarium_items_count.json", %{count: count}) do
    count
  end
end
