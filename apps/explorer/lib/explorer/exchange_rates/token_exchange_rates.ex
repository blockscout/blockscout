defmodule Explorer.ExchangeRates.TokenExchangeRates do
  @moduledoc """
  Periodically fetches fiat value of tokens.
  """
  use GenServer

  require Logger

  alias Explorer.ExchangeRates.Source
  alias Explorer.{Chain.Token, Repo}
  @batch_size 150
  @interval :timer.seconds(5)
  @refetch_interval :timer.hours(1)

  defstruct max_batch_size: @batch_size,
            interval: @interval,
            refetch_interval: @refetch_interval,
            tokens_to_fetch: nil

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    if Application.get_env(:explorer, __MODULE__)[:enabled] do
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
          interval: interval,
          refetch_interval: refetch_interval,
          tokens_to_fetch: nil
        } = state
      ) do
    case Source.fetch_token_hashes_with_market_data() do
      {:ok, contract_address_hashes} ->
        tokens = contract_address_hashes |> Token.tokens_by_contract_address_hashes() |> Repo.all()
        Process.send_after(self(), :fetch, interval)
        {:noreply, %{state | tokens_to_fetch: tokens}}

      {:error, err} ->
        Logger.error("Error while fetching tokens with market data (/coins/list): #{inspect(err)}")
        Process.send_after(self(), :fetch, refetch_interval)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(
        :fetch,
        %__MODULE__{
          refetch_interval: refetch_interval,
          tokens_to_fetch: []
        } = state
      ) do
    Process.send_after(self(), :fetch, refetch_interval)
    {:noreply, %{state | tokens_to_fetch: nil}}
  end

  @impl GenServer
  def handle_info(
        :fetch,
        %__MODULE__{
          max_batch_size: batch_size,
          interval: interval,
          tokens_to_fetch: tokens_to_fetch
        } = state
      ) do
    {fetch_now, fetch_later} = Enum.split(tokens_to_fetch, batch_size)

    case fetch_now |> Enum.map(& &1.contract_address_hash) |> Source.fetch_market_data_for_token_addresses() do
      {:ok, token_to_market_data} ->
        fetch_now |> Enum.each(&update_token(&1, token_to_market_data))

      err ->
        Logger.error("Error while fetching fiat values for tokens: #{inspect(err)}")
    end

    Process.send_after(self(), :fetch, interval)
    {:noreply, %{state | tokens_to_fetch: fetch_later}}
  end

  defp update_token(%{contract_address_hash: contract_address_hash} = token, token_to_market_data) do
    case Map.get(token_to_market_data, contract_address_hash) do
      %{} = market_data ->
        token
        |> Token.changeset(market_data)
        |> Repo.update(returning: false)

      _ ->
        nil
    end
  end
end
