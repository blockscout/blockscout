defmodule Indexer.Fetcher.TokenBalance do
  @moduledoc """
  Fetches token balances and sends the ones that were fetched to be imported in `Address.CurrentTokenBalance` and
  `Address.TokenBalance`.

  The module responsible for fetching token balances in the Smart Contract is the `Indexer.TokenBalances`. This module
  only prepares the params, sends them to `Indexer.TokenBalances` and relies on its return.

  It behaves as a `BufferedTask`, so we can configure the `max_batch_size` and the `max_concurrency` to control how many
  token balances will be fetched at the same time.

  Also, this module set a `retries_count` for each token balance and increment this number to avoid fetching the ones
  that always raise errors interacting with the Smart Contract.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Indexer.{BufferedTask, TokenBalances, Tracer}
  alias Indexer.Fetcher.TokenBalance.Supervisor, as: TokenBalanceSupervisor

  @behaviour BufferedTask

  @default_max_batch_size 100

  @max_retries 3

  @spec async_fetch([
          %{
            token_contract_address_hash: Hash.Address.t(),
            address_hash: Hash.Address.t(),
            block_number: non_neg_integer(),
            token_type: String.t(),
            token_id: non_neg_integer()
          }
        ]) :: :ok
  def async_fetch(token_balances) do
    if TokenBalanceSupervisor.disabled?() do
      :ok
    else
      formatted_params = Enum.map(token_balances, &entry/1)

      BufferedTask.buffer(__MODULE__, formatted_params, :infinity)
    end
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_unfetched_token_balances(
        initial,
        fn token_balance, acc ->
          token_balance
          |> entry()
          |> reducer.(acc)
        end,
        true
      )

    final
  end

  @doc """
  Fetches the given entries (token_balances) from the Smart Contract and import them in our database.

  It also increments the `retries_count` to avoid fetching token balances that always raise errors
  when reading their balance in the Smart Contract.
  """
  @impl BufferedTask
  @decorate trace(name: "fetch", resource: "Indexer.Fetcher.TokenBalance.run/2", tracer: Tracer, service: :indexer)
  def run(entries, _json_rpc_named_arguments) do
    result =
      entries
      |> Enum.map(&format_params/1)
      |> increase_retries_count()
      |> fetch_from_blockchain()
      |> import_token_balances()

    if result == :ok do
      :ok
    else
      {:retry, entries}
    end
  end

  def fetch_from_blockchain(params_list) do
    retryable_params_list =
      params_list
      |> Enum.filter(&(&1.retries_count <= @max_retries))
      |> Enum.uniq_by(&Map.take(&1, [:token_contract_address_hash, :token_id, :address_hash, :block_number]))

    Logger.metadata(count: Enum.count(retryable_params_list))

    %{fetched_token_balances: fetched_token_balances, failed_token_balances: _failed_token_balances} =
      1..@max_retries
      |> Enum.reduce_while(%{fetched_token_balances: [], failed_token_balances: retryable_params_list}, fn _x, acc ->
        {:ok,
         %{fetched_token_balances: _fetched_token_balances, failed_token_balances: failed_token_balances} =
           token_balances} = TokenBalances.fetch_token_balances_from_blockchain(acc.failed_token_balances)

        if Enum.empty?(failed_token_balances) do
          {:halt, token_balances}
        else
          failed_token_balances = increase_retries_count(failed_token_balances)

          token_balances_updated_retries_count =
            token_balances
            |> Map.put(:failed_token_balances, failed_token_balances)

          {:cont, token_balances_updated_retries_count}
        end
      end)

    fetched_token_balances
  end

  defp increase_retries_count(params_list) do
    params_list
    |> Enum.map(&Map.put(&1, :retries_count, &1.retries_count + 1))
  end

  def import_token_balances(token_balances_params) do
    addresses_params = format_and_filter_address_params(token_balances_params)
    formatted_token_balances_params = format_and_filter_token_balance_params(token_balances_params)

    import_params = %{
      addresses: %{params: addresses_params},
      address_token_balances: %{params: formatted_token_balances_params},
      address_current_token_balances: %{
        params: TokenBalances.to_address_current_token_balances(formatted_token_balances_params)
      },
      timeout: :infinity
    }

    case Chain.import(import_params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.debug(fn -> ["failed to import token balances: ", inspect(reason)] end,
          error_count: Enum.count(token_balances_params)
        )

        :error
    end
  end

  defp format_and_filter_address_params(token_balances_params) do
    token_balances_params
    |> Enum.map(&%{hash: &1.address_hash})
    |> Enum.uniq()
  end

  defp format_and_filter_token_balance_params(token_balances_params) do
    token_balances_params
    |> Enum.map(fn token_balance ->
      if token_balance.token_type do
        token_balance
      else
        put_token_type_to_balance_object(token_balance)
      end
    end)
  end

  defp put_token_type_to_balance_object(token_balance) do
    token_type = Chain.get_token_type(token_balance.token_contract_address_hash)

    if token_type do
      Map.put(token_balance, :token_type, token_type)
    else
      token_balance
    end
  end

  defp entry(
         %{
           token_contract_address_hash: token_contract_address_hash,
           address_hash: address_hash,
           block_number: block_number,
           token_type: token_type,
           token_id: token_id
         } = token_balance
       ) do
    retries_count = Map.get(token_balance, :retries_count, 0)

    token_id_int =
      case token_id do
        %Decimal{} -> Decimal.to_integer(token_id)
        id_int when is_integer(id_int) -> id_int
        _ -> token_id
      end

    {address_hash.bytes, token_contract_address_hash.bytes, block_number, token_type, token_id_int, retries_count}
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

  defp defaults do
    [
      flush_interval: 300,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      max_concurrency: 10,
      task_supervisor: Indexer.Fetcher.TokenBalance.TaskSupervisor
    ]
  end
end
