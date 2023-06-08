defmodule BlockScoutWeb.TransactionStateView do
  use BlockScoutWeb, :view

  alias Explorer.Chain
  alias Explorer.Chain.Wei

  import Explorer.Chain.Transaction.StateChange, only: [from_loss: 1, has_diff?: 1, to_profit: 1]

  def not_negative?(%Wei{value: val}) do
    not Decimal.negative?(val)
  end

  def not_negative?(val) do
    not Decimal.negative?(val)
  end

  def absolute_value_of(%Wei{value: val}) do
    %Wei{value: Decimal.abs(val)}
  end

  def absolute_value_of(val) do
    Decimal.abs(val)
  end

  def has_state_changes?(tx) do
    has_diff?(from_loss(tx)) or has_diff?(to_profit(tx))
  end

  def display_value(balance, :coin, _token_id) do
    format_wei_value(balance, :ether)
  end

  def display_value(balance, token_transfer, token_id) do
    render("_token_balance.html", transfer: token_transfer, balance: balance, token_id: token_id)
  end

  def display_erc_721(token_transfer) do
    render(BlockScoutWeb.TransactionView, "_total_transfers.html", transfer: token_transfer)
  end
end
