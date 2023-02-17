defmodule Explorer.ExchangeRates.TokenExchangeRates do
  @moduledoc """
  Periodically fethes fiat value of tokens.
  """
  use GenServer

  require Logger

  alias Explorer.{ExchangeRates, ExchangeRates.Source}
  alias Explorer.{Chain.Token, Repo}

  @batch_size 150
  @interval :timer.seconds(5)
  @refetch_interval :timer.hours(1)

  defstruct max_batch_size: @batch_size,
            interval: @interval,
            refetch_interval: @refetch_interval,
            last_fetched_token_contract_address: nil

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    if Application.get_env(:explorer, ExchangeRates)[:enabled] do
      state = %__MODULE__{
        max_batch_size: Application.get_env(:explorer, __MODULE__)[:max_batch_size] || @batch_size,
        interval: Application.get_env(:explorer, __MODULE__)[:interval] || @interval,
        refetch_interval: Application.get_env(:explorer, __MODULE__)[:refetch_interval] || @refetch_interval
      }

      Process.send_after(self(), :fetch, state.interval)

      {:ok, state}
    else
      :ignore
    end
  end

  @impl GenServer
  def handle_info(
        :fetch,
        %__MODULE__{
          max_batch_size: batch_size,
          interval: interval,
          refetch_interval: refetch_interval,
          last_fetched_token_contract_address: last_fetched
        } = state
      ) do
    tokens_to_update = last_fetched |> Token.tokens_to_update_fiat_value(batch_size) |> Repo.all()

    case tokens_to_update |> Enum.map(& &1.contract_address_hash) |> Source.fetch_fiat_value_for_token_addresses() do
      {:ok, fiat_values} ->
        timestamp = %{updated_at: DateTime.utc_now()}

        tokens_to_update
        |> Enum.each(fn %{contract_address_hash: contract_address_hash} = token ->
          token
          |> Token.changeset(Map.put(timestamp, :fiat_value, Map.get(fiat_values, contract_address_hash)))
          |> Repo.update(returning: false)
        end)

      err ->
        Logger.error("Error while fetching fiat values for tokens: #{inspect(err)}")
    end

    if length(tokens_to_update) < batch_size do
      Process.send_after(self(), :fetch, refetch_interval)
      {:noreply, %{state | last_fetched_token_contract_address: nil}}
    else
      Process.send_after(self(), :fetch, interval)
      {:noreply, %{state | last_fetched_token_contract_address: List.last(tokens_to_update).contract_address_hash}}
    end
  end
end
