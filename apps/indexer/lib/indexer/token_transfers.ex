defmodule Indexer.TokenTransfers do
  @moduledoc """
  Helper functions for transforming data for ERC-20 and ERC-721 token transfers.
  """

  alias ABI.TypeDecoder
  alias Explorer.Chain.TokenTransfer

  @doc """
  Returns a list of token transfers given a list of logs.
  """
  def from_log_params(logs) do
    initial_acc = %{tokens: [], token_transfers: []}

    logs
    |> Enum.filter(&(&1.first_topic == unquote(TokenTransfer.constant())))
    |> Enum.reduce(initial_acc, &do_from_log_params/2)
  end

  defp do_from_log_params(log, %{tokens: tokens, token_transfers: token_transfers}) do
    {token, token_transfer} = parse_params(log)

    %{
      tokens: [token | tokens],
      token_transfers: [token_transfer | token_transfers]
    }
  end

  # ERC-20 token transfer
  defp parse_params(%{fourth_topic: nil} = log) do
    token_transfer = %{
      amount: Decimal.new(convert_to_integer(log.data)),
      block_number: log.block_number,
      log_index: log.index,
      from_address_hash: truncate_address_hash(log.second_topic),
      to_address_hash: truncate_address_hash(log.third_topic),
      token_contract_address_hash: log.address_hash,
      transaction_hash: log.transaction_hash
    }

    token = %{
      contract_address_hash: log.address_hash,
      type: "ERC-20"
    }

    {token, token_transfer}
  end

  # ERC-721 token transfer
  defp parse_params(%{fourth_topic: fourth_topic} = log) when not is_nil(fourth_topic) do
    token_transfer = %{
      block_number: log.block_number,
      log_index: log.index,
      from_address_hash: truncate_address_hash(log.second_topic),
      to_address_hash: truncate_address_hash(log.third_topic),
      token_contract_address_hash: log.address_hash,
      token_id: convert_to_integer(fourth_topic),
      transaction_hash: log.transaction_hash
    }

    token = %{
      contract_address_hash: log.address_hash,
      type: "ERC-721"
    }

    {token, token_transfer}
  end

  defp truncate_address_hash(nil), do: "0x0000000000000000000000000000000000000000"

  defp truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
    "0x#{truncated_hash}"
  end

  defp convert_to_integer("0x"), do: 0

  defp convert_to_integer("0x" <> encoded_integer) do
    [value] =
      encoded_integer
      |> Base.decode16!(case: :mixed)
      |> TypeDecoder.decode_raw([{:uint, 256}])

    value
  end
end
