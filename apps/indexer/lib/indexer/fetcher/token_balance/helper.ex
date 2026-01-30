defmodule Indexer.Fetcher.TokenBalance.Helper do
  @moduledoc """
  Common functions for `Indexer.Fetcher.TokenBalance.Historical` and `Indexer.Fetcher.TokenBalance.Current` modules
  """

  require Logger

  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.Chain.Address.{CurrentTokenBalance, TokenBalance}
  alias Explorer.Chain.{Hash, Token}
  alias Explorer.Utility.MissingBalanceOfToken
  alias Indexer.{BufferedTask, TokenBalances}

  @default_max_batch_size 100
  @default_max_concurrency 10

  def async_fetch(module, token_balances, realtime?) do
    if Module.concat(module, Supervisor).disabled?() do
      :ok
    else
      filtered_balances =
        token_balances
        |> RangesHelper.filter_by_block_ranges()
        |> RangesHelper.filter_traceable_block_numbers()

      formatted_params = Enum.map(filtered_balances, &entry/1)

      BufferedTask.buffer(module, formatted_params, realtime?, :infinity)
    end
  end

  @doc false
  def child_spec([init_options, gen_server_options], module) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    if !state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{module}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      module
      |> defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{module, merged_init_opts}, gen_server_options]}, id: module)
  end

  def init(reducer, stream_func) do
    entry_reducer = fn token_balance, acc ->
      token_balance
      |> entry()
      |> reducer.(acc)
    end

    stream_reducer =
      entry_reducer
      |> RangesHelper.stream_reducer_by_block_ranges()
      |> RangesHelper.stream_reducer_traceable()

    {:ok, final} = stream_func.(stream_reducer)

    final
  end

  def format_and_filter_address_params(token_balances_params) do
    token_balances_params
    |> Enum.map(&%{hash: &1.address_hash})
    |> Enum.uniq()
  end

  def format_and_filter_token_balance_params(token_balances_params) do
    {params_without_type, params_with_type} = Enum.split_with(token_balances_params, &is_nil(&1.token_type))

    params_with_type ++ put_token_type_to_balance_objects(params_without_type)
  end

  def fetch_token_balances(entries) do
    params = Enum.map(entries, &format_params/1)

    missing_balance_of_tokens =
      params
      |> Enum.map(& &1.token_contract_address_hash)
      |> Enum.uniq()
      |> MissingBalanceOfToken.get_by_hashes()

    params
    |> MissingBalanceOfToken.filter_token_balances_params(true, missing_balance_of_tokens)
    |> fetch_from_blockchain(missing_balance_of_tokens)
  end

  defp put_token_type_to_balance_objects([]), do: []

  defp put_token_type_to_balance_objects(token_balances) do
    token_types_map =
      token_balances
      |> Enum.map(& &1.token_contract_address_hash)
      |> Token.get_token_types()
      |> Map.new()

    Enum.map(token_balances, &Map.put(&1, :token_type, token_types_map[&1.token_contract_address_hash]))
  end

  defp fetch_from_blockchain(params_list, missing_balance_of_tokens) do
    params_list =
      Enum.uniq_by(params_list, &Map.take(&1, [:token_contract_address_hash, :token_id, :address_hash, :block_number]))

    Logger.metadata(count: Enum.count(params_list))

    {:ok, %{fetched_token_balances: fetched_token_balances, failed_token_balances: failed_token_balances}} =
      TokenBalances.fetch_token_balances_from_blockchain(params_list)

    handle_success_balances(fetched_token_balances, missing_balance_of_tokens)
    failed_balances_to_keep = handle_failed_balances(failed_token_balances)

    fetched_token_balances ++ failed_balances_to_keep
  end

  defp handle_success_balances([], _missing_balance_of_tokens), do: :ok

  defp handle_success_balances(fetched_token_balances, missing_balance_of_tokens) do
    successful_token_hashes =
      fetched_token_balances
      |> Enum.map(&to_string(&1.token_contract_address_hash))
      |> MapSet.new()

    missing_balance_of_token_hashes =
      missing_balance_of_tokens
      |> Enum.map(&to_string(&1.token_contract_address_hash))
      |> MapSet.new()

    successful_token_hashes
    |> MapSet.intersection(missing_balance_of_token_hashes)
    |> MapSet.to_list()
    |> MissingBalanceOfToken.mark_as_implemented()
  end

  defp handle_failed_balances([]), do: []

  defp handle_failed_balances(failed_token_balances) do
    failed_token_balances
    |> handle_missing_balance_of_tokens()
    |> handle_other_errors()
  end

  defp handle_missing_balance_of_tokens(failed_token_balances) do
    {missing_balance_of_balances, other_failed_balances} =
      Enum.split_with(failed_token_balances, &EthereumJSONRPC.contract_failure?/1)

    MissingBalanceOfToken.insert_from_params(missing_balance_of_balances)

    missing_balance_of_balances
    |> Enum.group_by(& &1.token_contract_address_hash, & &1.block_number)
    |> Enum.map(fn {token_contract_address_hash, block_numbers} ->
      {token_contract_address_hash, Enum.max(block_numbers)}
    end)
    |> Enum.each(fn {token_contract_address_hash, block_number} ->
      TokenBalance.delete_placeholders_below(token_contract_address_hash, block_number)
      CurrentTokenBalance.delete_placeholders_below(token_contract_address_hash, block_number)
    end)

    other_failed_balances
  end

  defp handle_other_errors(failed_token_balances) do
    Enum.map(failed_token_balances, fn token_balance_params ->
      new_retries_count = token_balance_params.retries_count + 1

      Map.merge(token_balance_params, %{
        retries_count: new_retries_count,
        refetch_after: define_refetch_after(new_retries_count)
      })
    end)
  end

  defp define_refetch_after(retries_count) do
    config = Application.get_env(:indexer, Indexer.Fetcher.TokenBalance.Historical)

    coef = config[:exp_timeout_coeff]
    max_refetch_interval = config[:max_refetch_interval]
    max_retries_count = :math.log(max_refetch_interval / 1000 / coef)

    value = floor(coef * :math.exp(min(retries_count, max_retries_count)))

    Timex.shift(Timex.now(), seconds: value)
  end

  defp entry(
         %{
           token_contract_address_hash: token_contract_address_hash,
           address_hash: address_hash,
           block_number: block_number,
           token_type: token_type,
           token_id: token_id
         } = params
       ) do
    token_id_int =
      case token_id do
        %Decimal{} -> Decimal.to_integer(token_id)
        id_int when is_integer(id_int) -> id_int
        _ -> token_id
      end

    {
      address_hash.bytes,
      token_contract_address_hash.bytes,
      block_number,
      token_type,
      token_id_int,
      Map.get(params, :retries_count) || 0
    }
  end

  defp format_params(
         {address_hash_bytes, token_contract_address_hash_bytes, block_number, token_type, token_id, retries_count}
       ) do
    {:ok, token_contract_address_hash} = Hash.Address.cast(token_contract_address_hash_bytes)
    {:ok, address_hash} = Hash.Address.cast(address_hash_bytes)

    %{
      token_contract_address_hash: to_string(token_contract_address_hash),
      address_hash: to_string(address_hash),
      block_number: block_number,
      retries_count: retries_count,
      token_type: token_type,
      token_id: token_id
    }
  end

  defp defaults(module) do
    [
      flush_interval: 300,
      max_batch_size: Application.get_env(:indexer, module)[:batch_size] || @default_max_batch_size,
      max_concurrency: Application.get_env(:indexer, module)[:concurrency] || @default_max_concurrency,
      task_supervisor: Module.concat(module, TaskSupervisor)
    ]
  end
end
