defmodule Indexer.Fetcher.CoinBalance do
  @moduledoc """
  Fetches `t:Explorer.Chain.Address.CoinBalance.t/0` and updates `t:Explorer.Chain.Address.t/0` `fetched_coin_balance` and
  `fetched_coin_balance_block_number` to value at max `t:Explorer.Chain.Address.CoinBalance.t/0` `block_number` for the given `t:Explorer.Chain.Address.t/` `hash`.
  """

  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]

  alias EthereumJSONRPC.{Blocks, FetchedBalances}
  alias Explorer.Chain
  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Chain.Cache.Accounts
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.CoinBalance.Supervisor, as: CoinBalanceSupervisor

  @behaviour BufferedTask

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 150,
    max_concurrency: 2,
    task_supervisor: Indexer.Fetcher.CoinBalance.TaskSupervisor,
    metadata: [fetcher: :coin_balance]
  ]

  @doc """
  Asynchronously fetches balances for each address `hash` at the `block_number`.
  """
  @spec async_fetch_balances([
          %{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}
        ]) :: :ok
  def async_fetch_balances(balance_fields) when is_list(balance_fields) do
    if CoinBalanceSupervisor.disabled?() do
      :ok
    else
      entries = Enum.map(balance_fields, &entry/1)

      BufferedTask.buffer(__MODULE__, entries)
    end
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_options =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_options}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_unfetched_balances(initial, fn address_fields, acc ->
        address_fields
        |> entry()
        |> reducer.(acc)
      end)

    final
  end

  @impl BufferedTask
  @decorate trace(name: "fetch", resource: "Indexer.Fetcher.CoinBalance.run/2", service: :indexer, tracer: Tracer)
  def run(entries, json_rpc_named_arguments) do
    # the same address may be used more than once in the same block, but we only want one `Balance` for a given
    # `{address, block}`, so take unique params only
    unique_entries = Enum.uniq(entries)

    unique_filtered_entries =
      Enum.filter(unique_entries, fn {_hash, block_number} ->
        block_number >= EthereumJSONRPC.first_block_to_fetch(:trace_first_block)
      end)

    unique_entry_count = Enum.count(unique_filtered_entries)
    Logger.metadata(count: unique_entry_count)

    Logger.debug(fn -> "fetching" end)

    unique_filtered_entries
    |> Enum.map(&entry_to_params/1)
    |> EthereumJSONRPC.fetch_balances(json_rpc_named_arguments)
    |> case do
      {:ok, fetched_balances} ->
        run_fetched_balances(fetched_balances, unique_filtered_entries)

      {:error, reason} ->
        Logger.error(
          fn ->
            ["failed to fetch: ", inspect(reason)]
          end,
          error_count: unique_entry_count
        )

        {:retry, unique_filtered_entries}
    end
  end

  defp entry_to_params({address_hash_bytes, block_number}) when is_integer(block_number) do
    {:ok, address_hash} = Hash.Address.cast(address_hash_bytes)
    %{block_quantity: integer_to_quantity(block_number), hash_data: to_string(address_hash)}
  end

  defp entry(%{address_hash: %Hash{bytes: address_hash_bytes}, block_number: block_number}) do
    {address_hash_bytes, block_number}
  end

  # We want to record all historical balances for an address, but have the address itself have balance from the
  # `Balance` with the greatest block_number for that address.
  def balances_params_to_address_params(balances_params) do
    balances_params
    |> Enum.group_by(fn %{address_hash: address_hash} -> address_hash end)
    |> Map.values()
    |> Stream.map(&Enum.max_by(&1, fn %{block_number: block_number} -> block_number end))
    |> Enum.map(fn %{address_hash: address_hash, block_number: block_number, value: value} ->
      %{hash: address_hash, fetched_coin_balance_block_number: block_number, fetched_coin_balance: value}
    end)
  end

  def import_fetched_balances(%FetchedBalances{params_list: params_list}, broadcast_type \\ false) do
    value_fetched_at = DateTime.utc_now()

    importable_balances_params = Enum.map(params_list, &Map.put(&1, :value_fetched_at, value_fetched_at))

    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    importable_balances_daily_params = balances_daily_params(params_list, json_rpc_named_arguments)

    addresses_params = balances_params_to_address_params(importable_balances_params)

    Chain.import(%{
      addresses: %{params: addresses_params, with: :balance_changeset},
      address_coin_balances: %{params: importable_balances_params},
      address_coin_balances_daily: %{params: importable_balances_daily_params},
      broadcast: broadcast_type
    })
  end

  def import_fetched_daily_balances(%FetchedBalances{params_list: params_list}, broadcast_type \\ false) do
    value_fetched_at = DateTime.utc_now()

    importable_balances_params = Enum.map(params_list, &Map.put(&1, :value_fetched_at, value_fetched_at))

    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    importable_balances_daily_params = balances_daily_params(params_list, json_rpc_named_arguments)

    addresses_params = balances_params_to_address_params(importable_balances_params)

    Chain.import(%{
      addresses: %{params: addresses_params, with: :balance_changeset},
      address_coin_balances_daily: %{params: importable_balances_daily_params},
      broadcast: broadcast_type
    })
  end

  defp run_fetched_balances(%FetchedBalances{errors: errors} = fetched_balances, _) do
    with {:ok, imported} <- import_fetched_balances(fetched_balances) do
      Accounts.drop(imported[:addresses])
    end

    retry(errors)
  end

  defp retry([]), do: :ok

  defp retry(errors) when is_list(errors) do
    retried_entries = fetched_balances_errors_to_entries(errors)

    Logger.error(
      fn ->
        [
          "failed to fetch: ",
          fetched_balance_errors_to_iodata(errors)
        ]
      end,
      error_count: Enum.count(retried_entries)
    )

    {:retry, retried_entries}
  end

  defp fetched_balances_errors_to_entries(errors) when is_list(errors) do
    Enum.map(errors, &fetched_balance_error_to_entry/1)
  end

  defp fetched_balance_error_to_entry(%{data: %{block_quantity: block_quantity, hash_data: hash_data}})
       when is_binary(block_quantity) and is_binary(hash_data) do
    {:ok, %Hash{bytes: address_hash_bytes}} = Hash.Address.cast(hash_data)
    block_number = quantity_to_integer(block_quantity)
    {address_hash_bytes, block_number}
  end

  defp fetched_balance_errors_to_iodata(errors) when is_list(errors) do
    fetched_balance_errors_to_iodata(errors, [])
  end

  defp fetched_balance_errors_to_iodata([], iodata), do: iodata

  defp fetched_balance_errors_to_iodata([error | errors], iodata) do
    fetched_balance_errors_to_iodata(errors, [iodata | fetched_balance_error_to_iodata(error)])
  end

  defp fetched_balance_error_to_iodata(%{
         code: code,
         message: message,
         data: %{block_quantity: block_quantity, hash_data: hash_data}
       })
       when is_integer(code) and is_binary(message) and is_binary(block_quantity) and is_binary(hash_data) do
    [hash_data, "@", quantity_to_integer(block_quantity), ": (", to_string(code), ") ", message, ?\n]
  end

  def block_timestamp_map(params_list, json_rpc_named_arguments) do
    block_numbers =
      params_list
      |> Enum.map(&Map.get(&1, :block_number))
      |> Enum.sort()
      |> Enum.dedup()

    Enum.reduce(block_numbers, %{}, fn block_number, map ->
      case EthereumJSONRPC.fetch_blocks_by_range(block_number..block_number, json_rpc_named_arguments) do
        {:ok, %Blocks{blocks_params: [%{timestamp: timestamp}]}} ->
          day = DateTime.to_date(timestamp)
          Map.put(map, "#{block_number}", day)

        _ ->
          %{}
      end
    end)
  end

  defp balances_daily_params(params_list, json_rpc_named_arguments) do
    block_timestamp_map = block_timestamp_map(params_list, json_rpc_named_arguments)

    params_list
    |> Enum.map(fn balance_param ->
      if Map.has_key?(block_timestamp_map, "#{balance_param.block_number}") do
        day = Map.get(block_timestamp_map, "#{balance_param.block_number}")

        incoming_balance_daily_param = %{
          address_hash: balance_param.address_hash,
          day: day,
          value: balance_param.value
        }

        incoming_balance_daily_param
      else
        nil
      end
    end)
  end
end
