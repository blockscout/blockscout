defmodule BlockScoutWeb.TransactionStateView do
  use BlockScoutWeb, :view

  alias Explorer.Chain
  alias Explorer.Chain.Wei

  import BlockScoutWeb.TransactionStateController, only: [from_loss: 1, to_profit: 1]

  def has_diff?(%Wei{value: val}) do
    not Decimal.eq?(val, Decimal.new(0))
  end

  def has_diff?(val) do
    not Decimal.eq?(val, Decimal.new(0))
  end

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

  def display_value(balance, :coin) do
    format_wei_value(balance, :ether)
  end

  def display_value(balance, token_transfer) do
    render("_token_balance.html", transfer: token_transfer, balance: balance)
  end

  def display_nft(token_transfer) do
    render(BlockScoutWeb.TransactionView, "_total_transfers.html", transfer: token_transfer)
  end
end
