defmodule Indexer.Transform.TokenTransfers do
  @moduledoc """
  Helper functions for transforming data for ERC-20 and ERC-721 token transfers.
  """

  require Logger

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]
  import Explorer.Helper, only: [decode_data: 2]

  alias Explorer.Repo
  alias Explorer.Chain.{Token, TokenTransfer}
  alias Indexer.Fetcher.TokenTotalSupplyUpdater

  @doc """
  Returns a list of token transfers given a list of logs.
  """
  def parse(logs) do
    initial_acc = %{tokens: [], token_transfers: []}

    erc20_and_erc721_token_transfers =
      logs
      |> Enum.filter(&(&1.first_topic == unquote(TokenTransfer.constant())))
      |> Enum.reduce(initial_acc, &do_parse/2)

    weth_transfers =
      logs
      |> Enum.filter(fn log ->
        log.first_topic == TokenTransfer.weth_deposit_signature() ||
          log.first_topic == TokenTransfer.weth_withdrawal_signature()
      end)
      |> Enum.reduce(initial_acc, &do_parse/2)

    erc1155_token_transfers =
      logs
      |> Enum.filter(fn log ->
        log.first_topic == TokenTransfer.erc1155_single_transfer_signature() ||
          log.first_topic == TokenTransfer.erc1155_batch_transfer_signature()
      end)
      |> Enum.reduce(initial_acc, &do_parse(&1, &2, :erc1155))

    rough_tokens =
      erc1155_token_transfers.tokens ++
        erc20_and_erc721_token_transfers.tokens ++ weth_transfers.tokens

    rough_token_transfers =
      erc1155_token_transfers.token_transfers ++
        erc20_and_erc721_token_transfers.token_transfers ++ weth_transfers.token_transfers

    {tokens, token_transfers} = sanitize_token_types(rough_tokens, rough_token_transfers)

    token_transfers
    |> Enum.filter(fn token_transfer ->
      token_transfer.to_address_hash == burn_address_hash_string() ||
        token_transfer.from_address_hash == burn_address_hash_string()
    end)
    |> Enum.map(fn token_transfer ->
      token_transfer.token_contract_address_hash
    end)
    |> Enum.uniq()
    |> TokenTotalSupplyUpdater.add_tokens()

    tokens_uniq = tokens |> Enum.uniq()

    token_transfers_from_logs_uniq = %{
      tokens: tokens_uniq,
      token_transfers: token_transfers
    }

    token_transfers_from_logs_uniq
  end

  defp sanitize_token_types(tokens, token_transfers) do
    existing_token_types_map =
      tokens
      |> Enum.reduce([], fn %{contract_address_hash: address_hash}, acc ->
        case Repo.get_by(Token, contract_address_hash: address_hash) do
          %{type: type} -> [{address_hash, type} | acc]
          _ -> acc
        end
      end)
      |> Map.new()

    existing_tokens =
      existing_token_types_map
      |> Map.keys()
      |> Enum.map(&to_string/1)

    new_tokens_token_transfers = Enum.filter(token_transfers, &(&1.token_contract_address_hash not in existing_tokens))

    new_token_types_map =
      new_tokens_token_transfers
      |> Enum.group_by(& &1.token_contract_address_hash)
      |> Enum.map(fn {contract_address_hash, transfers} ->
        {contract_address_hash, define_token_type(transfers)}
      end)
      |> Map.new()

    actual_token_types_map = Map.merge(new_token_types_map, existing_token_types_map)

    actual_tokens =
      Enum.map(tokens, fn %{contract_address_hash: hash} = token ->
        Map.put(token, :type, actual_token_types_map[hash])
      end)

    actual_token_transfers =
      Enum.map(token_transfers, fn %{token_contract_address_hash: hash} = tt ->
        Map.put(tt, :token_type, actual_token_types_map[hash])
      end)

    {actual_tokens, actual_token_transfers}
  end

  defp define_token_type(token_transfers) do
    Enum.reduce(token_transfers, nil, fn %{token_type: token_type}, acc ->
      if token_type_priority(token_type) > token_type_priority(acc), do: token_type, else: acc
    end)
  end

  defp token_type_priority(nil), do: -1

  @token_types_priority_order ["ERC-20", "ERC-721", "ERC-1155"]
  defp token_type_priority(token_type) do
    Enum.find_index(@token_types_priority_order, &(&1 == token_type))
  end

  defp do_parse(log, %{tokens: tokens, token_transfers: token_transfers} = acc, type \\ :erc20_erc721) do
    parse_result =
      if type != :erc1155 do
        parse_params(log)
      else
        parse_erc1155_params(log)
      end

    case parse_result do
      {token, token_transfer} ->
        %{
          tokens: [token | tokens],
          token_transfers: [token_transfer | token_transfers]
        }

      nil ->
        acc
    end
  rescue
    e in [FunctionClauseError, MatchError] ->
      Logger.error(fn ->
        ["Unknown token transfer format: #{inspect(log)}", Exception.format(:error, e, __STACKTRACE__)]
      end)

      acc
  end

  # ERC-20 token transfer
  defp parse_params(%{second_topic: second_topic, third_topic: third_topic, fourth_topic: nil} = log)
       when not is_nil(second_topic) and not is_nil(third_topic) do
    [amount] = decode_data(log.data, [{:uint, 256}])

    token_transfer = %{
      amount: Decimal.new(amount || 0),
      block_number: log.block_number,
      block_hash: log.block_hash,
      log_index: log.index,
      from_address_hash: truncate_address_hash(log.second_topic),
      to_address_hash: truncate_address_hash(log.third_topic),
      token_contract_address_hash: log.address_hash,
      transaction_hash: log.transaction_hash,
      token_ids: nil,
      token_type: "ERC-20"
    }

    token = %{
      contract_address_hash: log.address_hash,
      type: "ERC-20"
    }

    {token, token_transfer}
  end

  # ERC-20 token transfer for WETH
  defp parse_params(%{second_topic: second_topic, third_topic: nil, fourth_topic: nil} = log)
       when not is_nil(second_topic) do
    [amount] = decode_data(log.data, [{:uint, 256}])

    {from_address_hash, to_address_hash} =
      if log.first_topic == TokenTransfer.weth_deposit_signature() do
        {burn_address_hash_string(), truncate_address_hash(log.second_topic)}
      else
        {truncate_address_hash(log.second_topic), burn_address_hash_string()}
      end

    token_transfer = %{
      amount: Decimal.new(amount || 0),
      block_number: log.block_number,
      block_hash: log.block_hash,
      log_index: log.index,
      from_address_hash: from_address_hash,
      to_address_hash: to_address_hash,
      token_contract_address_hash: log.address_hash,
      transaction_hash: log.transaction_hash,
      token_ids: nil,
      token_type: "ERC-20"
    }

    token = %{
      contract_address_hash: log.address_hash,
      type: "ERC-20"
    }

    {token, token_transfer}
  end

  # ERC-721 token transfer with topics as addresses
  defp parse_params(%{second_topic: second_topic, third_topic: third_topic, fourth_topic: fourth_topic} = log)
       when not is_nil(second_topic) and not is_nil(third_topic) and not is_nil(fourth_topic) do
    [token_id] = decode_data(fourth_topic, [{:uint, 256}])

    token_transfer = %{
      block_number: log.block_number,
      log_index: log.index,
      block_hash: log.block_hash,
      from_address_hash: truncate_address_hash(log.second_topic),
      to_address_hash: truncate_address_hash(log.third_topic),
      token_contract_address_hash: log.address_hash,
      token_ids: [token_id || 0],
      transaction_hash: log.transaction_hash,
      token_type: "ERC-721"
    }

    token = %{
      contract_address_hash: log.address_hash,
      type: "ERC-721"
    }

    {token, token_transfer}
  end

  # ERC-721 token transfer with info in data field instead of in log topics
  defp parse_params(
         %{
           second_topic: nil,
           third_topic: nil,
           fourth_topic: nil,
           data: data
         } = log
       )
       when not is_nil(data) do
    [from_address_hash, to_address_hash, token_id] = decode_data(data, [:address, :address, {:uint, 256}])

    token_transfer = %{
      block_number: log.block_number,
      block_hash: log.block_hash,
      log_index: log.index,
      from_address_hash: encode_address_hash(from_address_hash),
      to_address_hash: encode_address_hash(to_address_hash),
      token_contract_address_hash: log.address_hash,
      token_ids: [token_id],
      transaction_hash: log.transaction_hash,
      token_type: "ERC-721"
    }

    token = %{
      contract_address_hash: log.address_hash,
      type: "ERC-721"
    }

    {token, token_transfer}
  end

  def parse_erc1155_params(
        %{
          first_topic: unquote(TokenTransfer.erc1155_batch_transfer_signature()),
          third_topic: third_topic,
          fourth_topic: fourth_topic,
          data: data
        } = log
      ) do
    [token_ids, values] = decode_data(data, [{:array, {:uint, 256}}, {:array, {:uint, 256}}])

    if token_ids == [] || values == [] do
      nil
    else
      token_transfer = %{
        block_number: log.block_number,
        block_hash: log.block_hash,
        log_index: log.index,
        from_address_hash: truncate_address_hash(third_topic),
        to_address_hash: truncate_address_hash(fourth_topic),
        token_contract_address_hash: log.address_hash,
        transaction_hash: log.transaction_hash,
        token_type: "ERC-1155",
        token_ids: token_ids,
        amounts: values
      }

      token = %{
        contract_address_hash: log.address_hash,
        type: "ERC-1155"
      }

      {token, token_transfer}
    end
  end

  def parse_erc1155_params(%{third_topic: third_topic, fourth_topic: fourth_topic, data: data} = log) do
    [token_id, value] = decode_data(data, [{:uint, 256}, {:uint, 256}])

    token_transfer = %{
      amount: value,
      block_number: log.block_number,
      block_hash: log.block_hash,
      log_index: log.index,
      from_address_hash: truncate_address_hash(third_topic),
      to_address_hash: truncate_address_hash(fourth_topic),
      token_contract_address_hash: log.address_hash,
      transaction_hash: log.transaction_hash,
      token_type: "ERC-1155",
      token_ids: [token_id]
    }

    token = %{
      contract_address_hash: log.address_hash,
      type: "ERC-1155"
    }

    {token, token_transfer}
  end

  defp truncate_address_hash(nil), do: burn_address_hash_string()

  defp truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
    "0x#{truncated_hash}"
  end

  defp encode_address_hash(binary) do
    "0x" <> Base.encode16(binary, case: :lower)
  end
end
