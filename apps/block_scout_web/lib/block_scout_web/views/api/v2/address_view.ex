defmodule BlockScoutWeb.API.V2.AddressView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{ApiView, Helper}
  alias BlockScoutWeb.{ABIEncodedValueView, TransactionView}
  alias BlockScoutWeb.Tokens.Helpers
  alias Explorer.ExchangeRates.Token
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.{Block, InternalTransaction, Log, Transaction, Wei}
  alias Explorer.Counters.AverageBlockTime
  alias Timex.Duration

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("address.json", %{address: address}) do
    %{}
  end
end
