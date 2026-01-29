defmodule Indexer.Fetcher.TokenBalance.Historical do
  @moduledoc """
  Fetches historical token balances and sends the ones that were fetched to be imported in `Address.TokenBalance`.

  The module responsible for fetching token balances in the Smart Contract is the `Indexer.TokenBalances`. This module
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
  alias Explorer.Chain.Address.TokenBalance
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
              token_id: non_neg_integer() | nil
            }
          ],
          boolean()
        ) :: :ok
  def async_fetch(token_balances, realtime?) do
    Helper.async_fetch(__MODULE__, token_balances, realtime?)
  end

  @doc false
  def child_spec(args) do
    Helper.child_spec(args, __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    Helper.init(reducer, &TokenBalance.stream_unfetched_token_balances(initial, &1, true))
  end

  @doc """
  Fetches the given entries (token balances) from the smart contract and imports them.

  It also sets `refetch_after` on failure to avoid repeated smart contract errors.

  ## Parameters
  - `entries`: Token balance entries to fetch.
  - `json_rpc_named_arguments`: JSON-RPC configuration (unused).

  ## Returns
  - `:ok` on success
  - `{:retry, entries}` on failure
  """
  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.TokenBalance.Historical.run/2",
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

  def import_token_balances(token_balances_params) do
    addresses_params = Helper.format_and_filter_address_params(token_balances_params)
    formatted_token_balances_params = Helper.format_and_filter_token_balance_params(token_balances_params)

    import_params = %{
      addresses: %{params: addresses_params},
      address_token_balances: %{params: formatted_token_balances_params},
      timeout: @timeout
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
end
