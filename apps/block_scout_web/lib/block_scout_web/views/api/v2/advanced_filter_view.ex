defmodule BlockScoutWeb.API.V2.AdvancedFilterView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{Helper, TokenTransferView, TokenView, TransactionView}
  alias Explorer.Chain.{Address, Data, Transaction}

  def render("advanced_filters.json", %{
        advanced_filters: advanced_filters,
        decoded_transactions: decoded_transactions,
        search_params: %{
          method_ids: method_ids,
          tokens: tokens
        },
        next_page_params: next_page_params
      }) do
    %{
      items:
        advanced_filters
        |> Enum.zip(decoded_transactions)
        |> Enum.map(fn {af, decoded_input} -> prepare_advanced_filter(af, decoded_input) end),
      search_params: prepare_search_params(method_ids, tokens),
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
      status: TransactionView.format_status(advanced_filter.status),
      method:
        if(advanced_filter.created_from == :token_transfer,
          do:
            Transaction.method_name(
              %Transaction{
                to_address: %Address{
                  hash: advanced_filter.token_transfer.token.contract_address_hash,
                  contract_code: "0x" |> Data.cast() |> elem(1)
                },
                input: advanced_filter.input
              },
              decoded_input
            ),
          else:
            Transaction.method_name(
              %Transaction{to_address: advanced_filter.to_address, input: advanced_filter.input},
              decoded_input
            )
        ),
      from:
        Helper.address_with_info(
          nil,
          advanced_filter.from_address,
          advanced_filter.from_address_hash,
          false
        ),
      to:
        Helper.address_with_info(
          nil,
          advanced_filter.to_address,
          advanced_filter.to_address_hash,
          false
        ),
      created_contract:
        Helper.address_with_info(
          nil,
          advanced_filter.created_contract_address,
          advanced_filter.created_contract_address_hash,
          false
        ),
      value: advanced_filter.value,
      total:
        if(advanced_filter.created_from == :token_transfer,
          do: TokenTransferView.prepare_token_transfer_total(advanced_filter.token_transfer),
          else: nil
        ),
      token:
        if(advanced_filter.created_from == :token_transfer,
          do: TokenView.render("token.json", %{token: advanced_filter.token_transfer.token}),
          else: nil
        ),
      timestamp: advanced_filter.timestamp,
      block_number: advanced_filter.block_number,
      transaction_index: advanced_filter.transaction_index,
      internal_transaction_index: advanced_filter.internal_transaction_index,
      token_transfer_index: advanced_filter.token_transfer_index,
      token_transfer_batch_index: advanced_filter.token_transfer_batch_index,
      fee: advanced_filter.fee
    }
  end

  defp prepare_search_params(method_ids, tokens) do
    tokens_map =
      Map.new(tokens, fn {contract_address_hash, token} ->
        {contract_address_hash, TokenView.render("token.json", %{token: token})}
      end)

    %{methods: method_ids, tokens: tokens_map}
  end
end
