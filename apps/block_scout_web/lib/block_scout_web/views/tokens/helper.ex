defmodule BlockScoutWeb.Tokens.Helper do
  @moduledoc """
  Helper functions for interacting with `t:BlockScoutWeb.Chain.Token` attributes.
  """

  alias BlockScoutWeb.{AddressView, CurrencyHelper}
  alias Explorer.Chain.{Address, Token}

  @doc """
  Returns the token transfers' amount according to the token's type and decimals.

  When the token's type is ERC-20 or ZRC-2, then we are going to format the amount according to the token's
  decimals considering 0 when the decimals is nil. Case the amount is nil, this function will
  return the symbol `--`.

  When the token's type is ERC-721, the function will return a string with the token_id that
  represents the ERC-721 token since this kind of token doesn't have amount and decimals.
  """
  def token_transfer_amount(%{
        token: token,
        token_type: token_type,
        amount: amount,
        amounts: amounts,
        token_ids: token_ids
      }) do
    do_token_transfer_amount(token, token_type, amount, amounts, token_ids)
  end

  def token_transfer_amount(%{token: token, token_type: token_type, amount: amount, token_ids: token_ids}) do
    do_token_transfer_amount(token, token_type, amount, nil, token_ids)
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount(%Token{type: "ERC-20"}, nil, nil, nil, _token_ids) do
    {:ok, "--"}
  end

  defp do_token_transfer_amount(_token, "ERC-20", nil, nil, _token_ids) do
    {:ok, "--"}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount(%Token{type: "ERC-20", decimals: nil}, nil, amount, _amounts, _token_ids) do
    {:ok, CurrencyHelper.format_according_to_decimals(amount, Decimal.new(0))}
  end

  defp do_token_transfer_amount(%Token{decimals: nil}, "ERC-20", amount, _amounts, _token_ids) do
    {:ok, CurrencyHelper.format_according_to_decimals(amount, Decimal.new(0))}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount(%Token{type: "ERC-20", decimals: decimals}, nil, amount, _amounts, _token_ids) do
    {:ok, CurrencyHelper.format_according_to_decimals(amount, decimals)}
  end

  defp do_token_transfer_amount(%Token{decimals: decimals}, "ERC-20", amount, _amounts, _token_ids) do
    {:ok, CurrencyHelper.format_according_to_decimals(amount, decimals)}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount(%Token{type: "ZRC-2"}, nil, nil, nil, _token_ids) do
    {:ok, "--"}
  end

  defp do_token_transfer_amount(_token, "ZRC-2", nil, nil, _token_ids) do
    {:ok, "--"}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount(%Token{type: "ZRC-2", decimals: nil}, nil, amount, _amounts, _token_ids) do
    {:ok, CurrencyHelper.format_according_to_decimals(amount, Decimal.new(0))}
  end

  defp do_token_transfer_amount(%Token{decimals: nil}, "ZRC-2", amount, _amounts, _token_ids) do
    {:ok, CurrencyHelper.format_according_to_decimals(amount, Decimal.new(0))}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount(%Token{type: "ZRC-2", decimals: decimals}, nil, amount, _amounts, _token_ids) do
    {:ok, CurrencyHelper.format_according_to_decimals(amount, decimals)}
  end

  defp do_token_transfer_amount(%Token{decimals: decimals}, "ZRC-2", amount, _amounts, _token_ids) do
    {:ok, CurrencyHelper.format_according_to_decimals(amount, decimals)}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount(%Token{type: "ERC-721"}, nil, _amount, _amounts, _token_ids) do
    {:ok, :erc721_instance}
  end

  defp do_token_transfer_amount(_token, "ERC-721", _amount, _amounts, _token_ids) do
    {:ok, :erc721_instance}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount(%Token{type: type, decimals: decimals}, nil, amount, amounts, token_ids)
       when type in ["ERC-1155", "ERC-404"] do
    if amount do
      {:ok, :erc1155_erc404_instance, CurrencyHelper.format_according_to_decimals(amount, decimals)}
    else
      {:ok, :erc1155_erc404_instance, amounts, token_ids, decimals}
    end
  end

  defp do_token_transfer_amount(%Token{decimals: decimals}, type, amount, amounts, token_ids)
       when type in ["ERC-1155", "ERC-404"] do
    if amount do
      {:ok, :erc1155_erc404_instance, CurrencyHelper.format_according_to_decimals(amount, decimals)}
    else
      {:ok, :erc1155_erc404_instance, amounts, token_ids, decimals}
    end
  end

  defp do_token_transfer_amount(%Token{decimals: _decimals}, "ERC-7984", _amount, _amounts, _token_ids) do
    {:ok, "*confidential*"}
  end

  defp do_token_transfer_amount(_token, _token_type, _amount, _amounts, _token_ids) do
    nil
  end

  def token_transfer_amount_for_api(%{
        token: token,
        token_type: token_type,
        amount: amount,
        amounts: amounts,
        token_ids: token_ids
      }) do
    do_token_transfer_amount_for_api(token, token_type, amount, amounts, token_ids)
  end

  def token_transfer_amount_for_api(%{token: token, token_type: token_type, amount: amount, token_ids: token_ids}) do
    do_token_transfer_amount_for_api(token, token_type, amount, nil, token_ids)
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount_for_api(%Token{type: "ERC-20"}, nil, nil, nil, _token_ids) do
    {:ok, nil}
  end

  defp do_token_transfer_amount_for_api(_token, "ERC-20", nil, nil, _token_ids) do
    {:ok, nil}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount_for_api(
         %Token{type: "ERC-20", decimals: decimals},
         nil,
         amount,
         _amounts,
         _token_ids
       ) do
    {:ok, amount, decimals}
  end

  defp do_token_transfer_amount_for_api(
         %Token{decimals: decimals},
         "ERC-20",
         amount,
         _amounts,
         _token_ids
       ) do
    {:ok, amount, decimals}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount_for_api(%Token{type: "ZRC-2"}, nil, nil, nil, _token_ids) do
    {:ok, nil}
  end

  defp do_token_transfer_amount_for_api(_token, "ZRC-2", nil, nil, _token_ids) do
    {:ok, nil}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount_for_api(
         %Token{type: "ZRC-2", decimals: decimals},
         nil,
         amount,
         _amounts,
         _token_ids
       ) do
    {:ok, amount, decimals}
  end

  defp do_token_transfer_amount_for_api(
         %Token{decimals: decimals},
         "ZRC-2",
         amount,
         _amounts,
         _token_ids
       ) do
    {:ok, amount, decimals}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount_for_api(%Token{type: "ERC-721"}, nil, _amount, _amounts, _token_ids) do
    {:ok, :erc721_instance}
  end

  defp do_token_transfer_amount_for_api(_token, "ERC-721", _amount, _amounts, _token_ids) do
    {:ok, :erc721_instance}
  end

  # TODO: remove this clause along with token transfer denormalization
  defp do_token_transfer_amount_for_api(
         %Token{type: type, decimals: decimals},
         nil,
         amount,
         amounts,
         token_ids
       )
       when type in ["ERC-1155", "ERC-404"] do
    if amount do
      {:ok, :erc1155_erc404_instance, amount, decimals}
    else
      {:ok, :erc1155_erc404_instance, amounts, token_ids, decimals}
    end
  end

  defp do_token_transfer_amount_for_api(
         %Token{decimals: decimals},
         type,
         amount,
         amounts,
         token_ids
       )
       when type in ["ERC-1155", "ERC-404"] do
    if amount do
      {:ok, :erc1155_erc404_instance, amount, decimals}
    else
      {:ok, :erc1155_erc404_instance, amounts, token_ids, decimals}
    end
  end

  defp do_token_transfer_amount_for_api(%Token{decimals: decimals}, "ERC-7984", _amount, _amounts, _token_ids) do
    {:ok, nil, decimals}
  end

  defp do_token_transfer_amount_for_api(_token, _token_type, _amount, _amounts, _token_ids) do
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
