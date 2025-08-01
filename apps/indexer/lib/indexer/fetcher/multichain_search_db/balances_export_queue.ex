defmodule Indexer.Fetcher.MultichainSearchDb.BalancesExportQueue do
  @moduledoc """
  Exports token and coin balances to Multichain Search DB service from the queue.
  """

  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Explorer.Chain.Wei
  alias Explorer.Chain.{Hash, MultichainSearchDb.BalancesExportQueue}
  alias Explorer.MicroserviceInterfaces.MultichainSearch

  alias Indexer.BufferedTask
  alias Indexer.Helper, as: IndexerHelper

  @behaviour BufferedTask

  @default_max_batch_size 1000
  @default_max_concurrency 10
  @failed_to_re_export_data_error "Batch balances export retry to the Multichain Search DB failed"

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.merge(state: [])

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      BalancesExportQueue.stream_multichain_db_balances_batch(
        initial_acc,
        fn data, acc ->
          IndexerHelper.reduce_if_queue_is_not_full(data, acc, reducer, __MODULE__)
        end,
        true
      )

    acc
  end

  @impl BufferedTask
  def run(data, _json_rpc_named_arguments) when is_list(data) do
    prepared_export_data = prepare_export_data(data)

    export_data_to_multichain(prepared_export_data)
  end

  defp export_data_to_multichain(prepared_export_data) do
    case MultichainSearch.batch_import(prepared_export_data) do
      {:ok, {:chunks_processed, result}} ->
        all_balances =
          result
          |> Enum.flat_map(fn params ->
            coin_balances = prepare_coin_balances_for_db_query(params[:address_coin_balances])
            token_balances = prepare_token_balances_for_db_query(params[:address_token_balances])

            coin_balances ++ token_balances
          end)

        unless Enum.empty?(all_balances) do
          all_balances
          |> BalancesExportQueue.delete_elements_from_queue_by_params()
        end

        :ok

      {:error, retry} ->
        Logger.error(fn ->
          ["#{@failed_to_re_export_data_error}", "#{inspect(prepared_export_data)}"]
        end)

        {:retry, retry}
    end
  end

  defp prepare_token_balances_for_db_query(token_balances) do
    token_balances
    |> Enum.map(fn token_balance ->
      %{
        address_hash: token_balance.address_hash,
        token_contract_address_hash_or_native: token_balance.token_address_hash,
        token_id:
          if(is_nil(token_balance.token_id),
            do: nil,
            else: token_balance.token_id |> Decimal.to_integer()
          ),
        value:
          if(is_nil(token_balance.value),
            do: nil,
            else: token_balance.value |> Wei.dump() |> elem(1) |> Decimal.to_integer()
          )
      }
    end)
  end

  defp prepare_coin_balances_for_db_query(coin_balances) do
    coin_balances
    |> Enum.map(fn coin_balance ->
      %{
        address_hash: coin_balance.address_hash,
        token_contract_address_hash_or_native: "native",
        token_id: nil,
        value:
          if(is_nil(coin_balance.value),
            do: nil,
            else: coin_balance.value |> Wei.dump() |> elem(1) |> Decimal.to_integer()
          )
      }
    end)
  end

  @doc """
  Prepares export data by separating balances into coin and token balances.

  ## Parameters

    - `export_data`: A list of maps, each containing:
      - `:address_hash` - The address hash of Hash.Address.t().
      - `:token_contract_address_hash_or_native` - The token contract address hash as a binary, or the string `"native"` for native coins.
      - `:value` - The balance value as a `Decimal.t()`.
      - `:token_id` (optional) - The token ID, present for token balances.

  ## Returns

  A map with the following keys:
    - `:address_coin_balances` - A list of maps with `:address_hash` and `:value` for native coin balances.
    - `:address_token_balances` - A list of maps with `:address_hash`, `:token_contract_address_hash`, `:token_id`, and `:value` for token balances.

  Native coin balances are grouped under `:address_coin_balances`, while token balances are grouped under `:address_token_balances`. The function also converts binary hashes to string representations using the `Hash` struct.
  """
  @spec prepare_export_data([
          %{
            address_hash: Hash.Address.t(),
            token_contract_address_hash_or_native: binary(),
            value: Decimal.t() | nil,
            token_id: Decimal.t() | nil
          }
        ]) :: %{
          address_coin_balances: list(),
          address_token_balances: list()
        }
  def prepare_export_data(export_data) do
    pre_prepared_export_data =
      export_data
      |> Enum.reduce(
        %{
          address_coin_balances: [],
          address_token_balances: []
        },
        fn res, acc ->
          case res.token_contract_address_hash_or_native do
            "native" ->
              acc
              |> Map.update(
                :address_coin_balances,
                [%{address_hash: res.address_hash, value: res.value}],
                &[%{address_hash: res.address_hash, value: res.value} | &1]
              )

            _ ->
              acc
              |> Map.update(
                :address_token_balances,
                [
                  %{
                    address_hash: res.address_hash,
                    token_contract_address_hash:
                      to_string(%Hash{byte_count: 20, bytes: res.token_contract_address_hash_or_native}),
                    token_id: res.token_id,
                    value: res.value
                  }
                ],
                &[
                  %{
                    address_hash: res.address_hash,
                    token_contract_address_hash:
                      to_string(%Hash{byte_count: 20, bytes: res.token_contract_address_hash_or_native}),
                    token_id: res.token_id,
                    value: res.value
                  }
                  | &1
                ]
              )
          end
        end
      )

    pre_prepared_export_data
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(10),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
