defmodule BlockScoutWeb.Tokens.Helpers do
  @moduledoc """
  Helper functions for interacting with `t:BlockScoutWeb.Chain.Token` attributes.
  """

  alias BlockScoutWeb.{CurrencyHelpers}
  alias Explorer.Chain.{Address, Token}

  @doc """
  Returns the token transfers' amount according to the token's type and decimals.

  When the token's type is ERC-20, then we are going to format the amount according to the token's
  decimals considering 0 when the decimals is nil. Case the amount is nil, this function will
  return the symbol `--`.

  When the token's type is ERC-721, the function will return a string with the token_id that
  represents the ERC-721 token since this kind of token doesn't have amount and decimals.
  """
  def token_transfer_amount(%{token: token, amount: amount, token_id: token_id}) do
    do_token_transfer_amount(token, amount, token_id)
  end

  defp do_token_transfer_amount(%Token{type: "ERC-20"}, nil, _token_id) do
    {:ok, "--"}
  end

  defp do_token_transfer_amount(%Token{type: "ERC-20", decimals: nil}, amount, _token_id) do
    {:ok, CurrencyHelpers.format_according_to_decimals(amount, Decimal.new(0))}
  end

  defp do_token_transfer_amount(%Token{type: "ERC-20", decimals: decimals}, amount, _token_id) do
    {:ok, CurrencyHelpers.format_according_to_decimals(amount, decimals)}
  end

  defp do_token_transfer_amount(%Token{type: "ERC-721"}, _amount, _token_id) do
    {:ok, :erc721_instance}
  end

  defp do_token_transfer_amount(_token, _amount, _token_id) do
    nil
  end

  @doc """
  Returns the token's symbol.

  When the token's symbol is nil, the function will return the contract address hash.
  """
  def token_symbol(%Token{symbol: nil, contract_address_hash: address_hash}) do
    "#{contract_address_hash_truncated(address_hash)}..."
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
    "#{contract_address_hash_truncated(address_hash)}..."
  end

  defp build_token_name(%{name: name}) do
    name
  end

  defp contract_address_hash_truncated(address_hash) do
    address_hash
    |> to_string()
    |> String.slice(0..6)
  end
end
