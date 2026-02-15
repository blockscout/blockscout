defmodule Indexer.Fetcher.TokenBalance.Current do
  @moduledoc """
  Fetches current token balances and sends the ones that were fetched to be imported in `Address.CurrentTokenBalance`.

  The module responsible for fetching current token balances in the Smart Contract is the `Indexer.TokenBalances`. This module
  only prepares the params, sends them to `Indexer.TokenBalances` and relies on its return.

  It behaves as a `BufferedTask`, so we can configure the `max_batch_size` and the `max_concurrency` to control how many
  token balances will be fetched at the same time.

  Also, this module set a `refetch_after` for each token balance in case of failure to avoid fetching the ones
  that always raise errors interacting with the Smart Contract.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Hash
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.TokenBalance.Helper

  @behaviour BufferedTask

  @timeout :timer.minutes(10)

  @spec async_fetch(
          [
            %{
              token_contract_address_hash: Hash.Address.t(),
              address_hash: Hash.Address.t(),
              block_number: non_neg_integer(),
              token_type: String.t(),
              token_id: non_neg_integer()
            }
          ],
          boolean()
        ) :: :ok
  def async_fetch(current_token_balances, realtime?) do
    Helper.async_fetch(__MODULE__, current_token_balances, realtime?)
  end

  @doc false
  def child_spec(args) do
    Helper.child_spec(args, __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    Helper.init(reducer, &CurrentTokenBalance.stream_unfetched_current_token_balances(initial, &1, true))
  end

  @doc """
  Fetches the given entries (token_balances) from the Smart Contract and import them in our database.

  It also set the `refetch_after` in case of failure to avoid fetching token balances that always raise errors
  when reading their balance in the Smart Contract.
  """
  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.CurrentTokenBalance.run/2",
              tracer: Tracer,
              service: :indexer
            )
  def run(entries, _json_rpc_named_arguments) do
    entries
    |> Helper.fetch_token_balances()
    |> import_token_balances()
    |> case do
      :ok -> :ok
      _ -> {:retry, entries}
    end
  end

  def import_token_balances(ctb_params) do
    addresses_params = Helper.format_and_filter_address_params(ctb_params)
    formatted_current_token_balances_params = Helper.format_and_filter_token_balance_params(ctb_params)

    import_params = %{
      addresses: %{params: addresses_params},
      address_current_token_balances: %{params: formatted_current_token_balances_params},
      timeout: @timeout
    }

    case Chain.import(import_params) do
      {:ok, %{address_current_token_balances: imported_ctbs}} ->
        imported_ctbs
        |> Enum.group_by(& &1.address_hash)
        |> Enum.each(fn {address_hash, ctbs} ->
          Publisher.broadcast(
            %{
              address_current_token_balances: %{
                address_hash: to_string(address_hash),
                address_current_token_balances: ctbs
              }
            },
            :realtime
          )
        end)

      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.debug(fn -> ["failed to import current token balances: ", inspect(reason)] end,
          error_count: Enum.count(ctb_params)
        )

        :error
    end
  end
end
