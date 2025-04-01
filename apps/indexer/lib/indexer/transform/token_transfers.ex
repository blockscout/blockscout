defmodule Indexer.Transform.TokenTransfers do
  @moduledoc """
  Helper functions for transforming data for known token standards (ERC-20, ERC-721, ERC-1155, ERC-404) transfers.
  """

  require Logger

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]
  import Explorer.Helper, only: [decode_data: 2, truncate_address_hash: 1]

  alias Explorer.Repo
  alias Explorer.Chain.{Hash, Token, TokenTransfer}
  alias Indexer.Fetcher.TokenTotalSupplyUpdater

  @doc """
  Returns a list of token transfers given a list of logs.
  """
  def parse(logs, skip_additional_fetchers? \\ false) do
    initial_acc = %{tokens: [], token_transfers: []}

    erc20_and_erc721_token_transfers =
      logs
      |> Enum.filter(&(&1.first_topic == unquote(TokenTransfer.constant())))
      |> Enum.reduce(initial_acc, &do_parse/2)

    weth_transfers =
      logs
      |> Enum.filter(fn log ->
        (log.first_topic == TokenTransfer.weth_deposit_signature() ||
           log.first_topic == TokenTransfer.weth_withdrawal_signature()) &&
          TokenTransfer.whitelisted_weth_contract?(log.address_hash)
      end)
      |> Enum.reduce(initial_acc, &do_parse/2)
      |> drop_repeated_token_transfers(erc20_and_erc721_token_transfers.token_transfers)

    erc1155_token_transfers =
      logs
      |> Enum.filter(fn log ->
        log.first_topic == TokenTransfer.erc1155_single_transfer_signature() ||
          log.first_topic == TokenTransfer.erc1155_batch_transfer_signature()
      end)
      |> Enum.reduce(initial_acc, &do_parse(&1, &2, :erc1155))

    erc404_token_transfers =
      logs
      |> Enum.filter(fn log ->
        log.first_topic == TokenTransfer.erc404_erc20_transfer_event() ||
          log.first_topic == TokenTransfer.erc404_erc721_transfer_event()
      end)
      |> Enum.reduce(initial_acc, &do_parse(&1, &2, :erc404))

    rough_tokens =
      erc404_token_transfers.tokens ++
        erc1155_token_transfers.tokens ++
        erc20_and_erc721_token_transfers.tokens ++ weth_transfers.tokens

    rough_token_transfers =
      erc404_token_transfers.token_transfers ++
        erc1155_token_transfers.token_transfers ++
        erc20_and_erc721_token_transfers.token_transfers ++ weth_transfers.token_transfers

    tokens = sanitize_token_types(rough_tokens, rough_token_transfers)
    token_transfers = sanitize_weth_transfers(tokens, rough_token_transfers, weth_transfers.token_transfers)

    unless skip_additional_fetchers? do
      token_transfers
      |> filter_tokens_for_supply_update()
      |> TokenTotalSupplyUpdater.add_tokens()
    end

    tokens_uniq = tokens |> Enum.uniq()

    token_transfers_from_logs_uniq = %{
      tokens: tokens_uniq,
      token_transfers: token_transfers
    }

    token_transfers_from_logs_uniq
  end

  defp drop_repeated_token_transfers(weth_acc, erc_20_721_token_transfers) do
    key_from_tt = fn tt ->
      {tt.block_hash, tt.transaction_hash, tt.token_contract_address_hash, tt.to_address_hash, tt.from_address_hash,
       tt.amount}
    end

    deposit_withdrawal_like_transfers =
      Enum.reduce(erc_20_721_token_transfers, %{}, fn token_transfer, acc ->
        if token_transfer.token_type == "ERC-20" and
             (token_transfer.from_address_hash == burn_address_hash_string() or
                token_transfer.to_address_hash == burn_address_hash_string()) do
          Map.put(acc, key_from_tt.(token_transfer), true)
        else
          acc
        end
      end)

    %{token_transfers: weth_token_transfer} = weth_acc

    weth_token_transfer_updated =
      Enum.reject(weth_token_transfer, fn weth_tt ->
        deposit_withdrawal_like_transfers[key_from_tt.(weth_tt)]
      end)

    Map.put(weth_acc, :token_transfers, weth_token_transfer_updated)
  end

  defp sanitize_weth_transfers(total_tokens, total_transfers, weth_transfers) do
    existing_token_types_map =
      total_tokens
      |> Enum.map(&{&1.contract_address_hash, &1.type})
      |> Map.new()

    invalid_weth_transfers =
      Enum.reduce(weth_transfers, %{}, fn token_transfer, acc ->
        if existing_token_types_map[token_transfer.token_contract_address_hash] == "ERC-721" do
          Map.put(acc, token_transfer_to_key(token_transfer), true)
        else
          acc
        end
      end)

    total_transfers
    |> subtract_token_transfers(invalid_weth_transfers)
    |> Enum.reverse()
  end

  defp token_transfer_to_key(token_transfer) do
    {token_transfer.block_hash, token_transfer.transaction_hash, token_transfer.log_index}
  end

  defp subtract_token_transfers(tt_from, tt_to_subtract) do
    Enum.reduce(tt_from, [], fn tt, acc ->
      case tt_to_subtract[token_transfer_to_key(tt)] do
        nil -> [tt | acc]
        _ -> acc
      end
    end)
  end

  defp sanitize_token_types(tokens, token_transfers) do
    existing_token_types_map =
      tokens
      |> Enum.uniq()
      |> Enum.reduce([], fn %{contract_address_hash: address_hash}, acc ->
        case Repo.get_by(Token, contract_address_hash: address_hash) do
          %{type: type} -> [{address_hash, type} | acc]
          _ -> acc
        end
      end)
      |> Map.new()

    token_types_map =
      token_transfers
      |> Enum.group_by(& &1.token_contract_address_hash)
      |> Enum.map(fn {contract_address_hash, transfers} ->
        {contract_address_hash, define_token_type(transfers)}
      end)
      |> Map.new()

    actual_token_types_map =
      Map.merge(token_types_map, existing_token_types_map, fn _k, new_type, old_type ->
        if token_type_priority(old_type) > token_type_priority(new_type), do: old_type, else: new_type
      end)

    Enum.map(tokens, fn %{contract_address_hash: hash} = token ->
      Map.put(token, :type, actual_token_types_map[hash])
    end)
  end

  defp define_token_type(token_transfers) do
    Enum.reduce(token_transfers, nil, fn %{token_type: token_type}, acc ->
      if token_type_priority(token_type) > token_type_priority(acc), do: token_type, else: acc
    end)
  end

  defp token_type_priority(nil), do: -1

  @token_types_priority_order ["ERC-20", "ERC-721", "ERC-1155", "ERC-404"]
  defp token_type_priority(token_type) do
    Enum.find_index(@token_types_priority_order, &(&1 == token_type))
  end

  defp do_parse(log, %{tokens: tokens, token_transfers: token_transfers} = acc, type \\ :erc20_erc721) do
    parse_result =
      case type do
        :erc1155 -> parse_erc1155_params(log)
        :erc404 -> parse_erc404_params(log)
        _ -> parse_params(log)
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

    from_address_hash = truncate_address_hash(log.second_topic)
    to_address_hash = truncate_address_hash(log.third_topic)

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

    from_address_hash = truncate_address_hash(log.second_topic)
    to_address_hash = truncate_address_hash(log.third_topic)

    token_transfer = %{
      block_number: log.block_number,
      log_index: log.index,
      block_hash: log.block_hash,
      from_address_hash: from_address_hash,
      to_address_hash: to_address_hash,
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
      from_address_hash: "0x" <> Base.encode16(from_address_hash, case: :lower),
      to_address_hash: "0x" <> Base.encode16(to_address_hash, case: :lower),
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

  @spec parse_erc1155_params(map()) ::
          nil
          | {%{
               contract_address_hash: Hash.Address.t(),
               type: String.t()
             }, map()}
  defp parse_erc1155_params(
         %{
           first_topic: unquote(TokenTransfer.erc1155_batch_transfer_signature()),
           third_topic: third_topic,
           fourth_topic: fourth_topic,
           data: data
         } = log
       ) do
    [token_ids, values] = decode_data(data, [{:array, {:uint, 256}}, {:array, {:uint, 256}}])

    if is_nil(token_ids) or token_ids == [] or is_nil(values) or values == [] do
      nil
    else
      from_address_hash = truncate_address_hash(third_topic)
      to_address_hash = truncate_address_hash(fourth_topic)

      token_transfer = %{
        block_number: log.block_number,
        block_hash: log.block_hash,
        log_index: log.index,
        from_address_hash: from_address_hash,
        to_address_hash: to_address_hash,
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

  defp parse_erc1155_params(%{third_topic: third_topic, fourth_topic: fourth_topic, data: data} = log) do
    [token_id, value] = decode_data(data, [{:uint, 256}, {:uint, 256}])

    from_address_hash = truncate_address_hash(third_topic)
    to_address_hash = truncate_address_hash(fourth_topic)

    token_transfer = %{
      amount: value,
      block_number: log.block_number,
      block_hash: log.block_hash,
      log_index: log.index,
      from_address_hash: from_address_hash,
      to_address_hash: to_address_hash,
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

  @spec parse_erc404_params(map()) ::
          nil
          | {%{
               contract_address_hash: Hash.Address.t(),
               type: String.t()
             }, map()}
  defp parse_erc404_params(
         %{
           first_topic: unquote(TokenTransfer.erc404_erc20_transfer_event()),
           second_topic: second_topic,
           third_topic: third_topic,
           fourth_topic: nil,
           data: data
         } = log
       ) do
    [value] = decode_data(data, [{:uint, 256}])

    if is_nil(value) or value == [] do
      nil
    else
      token_transfer = %{
        block_number: log.block_number,
        block_hash: log.block_hash,
        log_index: log.index,
        from_address_hash: truncate_address_hash(second_topic),
        to_address_hash: truncate_address_hash(third_topic),
        token_contract_address_hash: log.address_hash,
        transaction_hash: log.transaction_hash,
        token_type: "ERC-404",
        token_ids: [],
        amounts: [value]
      }

      token = %{
        contract_address_hash: log.address_hash,
        type: "ERC-404"
      }

      {token, token_transfer}
    end
  end

  defp parse_erc404_params(
         %{
           first_topic: unquote(TokenTransfer.erc404_erc721_transfer_event()),
           second_topic: second_topic,
           third_topic: third_topic,
           fourth_topic: fourth_topic,
           data: _data
         } = log
       ) do
    [token_id] = decode_data(fourth_topic, [{:uint, 256}])

    if is_nil(token_id) or token_id == [] do
      nil
    else
      token_transfer = %{
        block_number: log.block_number,
        block_hash: log.block_hash,
        log_index: log.index,
        from_address_hash: truncate_address_hash(second_topic),
        to_address_hash: truncate_address_hash(third_topic),
        token_contract_address_hash: log.address_hash,
        transaction_hash: log.transaction_hash,
        token_type: "ERC-404",
        token_ids: [token_id],
        amounts: []
      }

      token = %{
        contract_address_hash: log.address_hash,
        type: "ERC-404"
      }

      {token, token_transfer}
    end
  end

  def filter_tokens_for_supply_update(token_transfers) do
    token_transfers
    |> Enum.filter(fn token_transfer ->
      token_transfer.to_address_hash == burn_address_hash_string() ||
        token_transfer.from_address_hash == burn_address_hash_string()
    end)
    |> Enum.map(& &1.token_contract_address_hash)
    |> Enum.uniq()
  end
end
