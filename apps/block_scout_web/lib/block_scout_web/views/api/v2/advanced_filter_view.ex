defmodule BlockScoutWeb.API.V2.AdvancedFilterView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{Helper, TokenView, TransactionView}
  alias Explorer.Chain.Transaction

  def render("advanced_filters.json", %{advanced_filters: advanced_filters, next_page_params: next_page_params}) do
    {decoded_transactions, _, _} =
      advanced_filters
      |> Enum.map(fn af -> %Transaction{to_address: af.to_address, input: af.input, hash: af.hash} end)
      |> TransactionView.decode_transactions(true)

    %{
      items:
        advanced_filters
        |> Enum.zip(decoded_transactions)
        |> Enum.map(fn {af, decoded_input} -> prepare_advanced_filter(af, decoded_input) end),
      next_page_params: next_page_params
    }
  end

  def render("methods.json", %{methods: methods}) do
    methods
  end

  defp prepare_advanced_filter(advanced_filter, decoded_input) do
    %{
      hash: advanced_filter.hash,
      type: advanced_filter.type,
      raw_input: advanced_filter.input,
      method:
        TransactionView.method_name(
          %Transaction{to_address: advanced_filter.to_address, input: advanced_filter.input},
          decoded_input
        ),
      from:
        Helper.address_with_info(
          nil,
          advanced_filter.from_address,
          advanced_filter.from_address.hash,
          true
        ),
      to:
        Helper.address_with_info(
          nil,
          advanced_filter.to_address,
          advanced_filter.to_address.hash,
          true
        ),
      value: advanced_filter.value,
      total:
        if(advanced_filter.type != "coin_transfer",
          do: TransactionView.prepare_token_transfer_total(advanced_filter.token_transfer),
          else: nil
        ),
      token:
        if(advanced_filter.type != "coin_transfer",
          do: TokenView.render("token.json", %{token: advanced_filter.token}),
          else: nil
        ),
      timestamp: advanced_filter.timestamp,
      block_number: advanced_filter.block_number,
      transaction_index: advanced_filter.transaction_index,
      internal_transaction_index: advanced_filter.internal_transaction_index,
      token_transfer_index: advanced_filter.token_transfer_index
    }
  end
end
