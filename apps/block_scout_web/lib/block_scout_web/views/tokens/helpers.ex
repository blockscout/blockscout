defmodule BlockScoutWeb.Tokens.Helpers do
  @moduledoc """
  Helper functions for interacting with `t:BlockScoutWeb.Chain.Token` attributes.
  """

  alias BlockScoutWeb.{AddressView, CurrencyHelpers}
  alias Explorer.Chain.{Address, Token}

  @doc """
  Returns the token transfers' amount according to the token's type and decimals.

  When the token's type is ERC-20, then we are going to format the amount according to the token's
  decimals considering 0 when the decimals is nil. Case the amount is nil, this function will
  return the symbol `--`.

  When the token's type is ERC-721, the function will return a string with the token_id that
  represents the ERC-721 token since this kind of token doesn't have amount and decimals.
  """
  def token_transfer_amount(%{token: token, amount: amount, amounts: amounts, token_ids: token_ids}) do
    do_token_transfer_amount(token, amount, amounts, token_ids)
  end

  def token_transfer_amount(%{token: token, amount: amount, token_ids: token_ids}) do
    do_token_transfer_amount(token, amount, nil, token_ids)
  end

  defp do_token_transfer_amount(%Token{type: "ERC-20"}, nil, nil, _token_ids) do
    {:ok, "--"}
  end

  defp do_token_transfer_amount(%Token{type: "ERC-20", decimals: nil}, amount, _amounts, _token_ids) do
    {:ok, CurrencyHelpers.format_according_to_decimals(amount, Decimal.new(0))}
  end

  defp do_token_transfer_amount(%Token{type: "ERC-20", decimals: decimals}, amount, _amounts, _token_ids) do
    {:ok, CurrencyHelpers.format_according_to_decimals(amount, decimals)}
  end

  defp do_token_transfer_amount(%Token{type: "ERC-721"}, _amount, _amounts, _token_ids) do
    {:ok, :erc721_instance}
  end

  defp do_token_transfer_amount(%Token{type: "ERC-1155", decimals: decimals}, amount, amounts, token_ids) do
    if amount do
      {:ok, :erc1155_instance, CurrencyHelpers.format_according_to_decimals(amount, decimals)}
    else
      {:ok, :erc1155_instance, amounts, token_ids, decimals}
    end
  end

  defp do_token_transfer_amount(_token, _amount, _amounts, _token_ids) do
    nil
  end

  def token_transfer_amount_for_api(%{
        token: token,
        amount: amount,
        amounts: amounts,
        token_ids: token_ids
      }) do
    do_token_transfer_amount_for_api(token, amount, amounts, token_ids)
  end

  def token_transfer_amount_for_api(%{token: token, amount: amount, token_ids: token_ids}) do
    do_token_transfer_amount_for_api(token, amount, nil, token_ids)
  end

  defp do_token_transfer_amount_for_api(%Token{type: "ERC-20"}, nil, nil, _token_ids) do
    {:ok, nil}
  end

  defp do_token_transfer_amount_for_api(
         %Token{type: "ERC-20", decimals: decimals},
         amount,
         _amounts,
         _token_ids
       ) do
    {:ok, amount, decimals}
  end

  defp do_token_transfer_amount_for_api(%Token{type: "ERC-721"}, _amount, _amounts, _token_ids) do
    {:ok, :erc721_instance}
  end

  defp do_token_transfer_amount_for_api(
         %Token{type: "ERC-1155", decimals: decimals},
         amount,
         amounts,
         token_ids
       ) do
    if amount do
      {:ok, :erc1155_instance, amount, decimals}
    else
      {:ok, :erc1155_instance, amounts, token_ids, decimals}
    end
  end

  defp do_token_transfer_amount_for_api(_token, _amount, _amounts, _token_ids) do
    nil
  end

  @doc """
  Returns the token's symbol.

  When the token's symbol is nil, the function will return the contract address hash.
  """
  def token_symbol(%Token{symbol: nil, contract_address_hash: address_hash}) do
    AddressView.short_hash_left_right(address_hash)
  end

  def token_symbol(%Token{symbol: symbol}) do
    symbol
  end

  @doc """
  Returns the token's name.

  When the token's name is nil, the function will return the contract address hash.
  """
  def token_name(%Token{} = token), do: build_token_name(token)
  def token_name(%Address.Token{} = address_token), do: build_token_name(address_token)

  defp build_token_name(%{name: nil, contract_address_hash: address_hash}) do
    AddressView.short_hash_left_right(address_hash)
  end

  defp build_token_name(%{name: name}) do
    name
  end
end
