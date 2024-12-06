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
            tokens_to_fetch: nil,
            source: Source.CoinGecko,
            cryptorank_limit: 1000,
            cryptorank_offset: 0,
            cryptorank_total_count: nil,
            remaining_tokens: nil

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
        refetch_interval: Application.get_env(:explorer, __MODULE__)[:refetch_interval] || @refetch_interval,
        source: Application.get_env(:explorer, __MODULE__)[:source],
        cryptorank_limit: Application.get_env(:explorer, Source.Cryptorank)[:limit],
        cryptorank_offset: 0,
        cryptorank_total_count: nil,
        remaining_tokens: nil
      }

      schedule_first_fetching(state)

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

  def handle_info(:cryptorank_fetch, %{remaining_tokens: remaining_tokens} = state)
      when is_integer(remaining_tokens) and remaining_tokens <= 0 do
    Process.send_after(self(), :cryptorank_fetch, state.refetch_interval)

    {:noreply, %{state | cryptorank_total_count: nil, cryptorank_offset: 0, remaining_tokens: nil}}
  end

  def handle_info(:cryptorank_fetch, state) do
    case Source.cryptorank_fetch_currencies(state.cryptorank_limit, state.cryptorank_offset) do
      {:ok, result} ->
        {count, tokens} = Map.pop(result, :count)

        tokens
        |> Enum.each(&update_token/1)

        count = state.cryptorank_total_count || count
        cryptorank_offset = state.cryptorank_offset + state.cryptorank_limit
        Process.send_after(self(), :cryptorank_fetch, state.interval)

        {:noreply,
         %{
           state
           | cryptorank_offset: cryptorank_offset,
             cryptorank_total_count: count,
             remaining_tokens: count - cryptorank_offset
         }}

      err ->
        Logger.error("Error while fetching cryptorank.io token prices: #{inspect(err)}")
        Process.send_after(self(), :cryptorank_fetch, state.refetch_interval)
        {:noreply, state}
    end
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

  defp update_token({nil, _params}) do
    :ignore
  end

  defp update_token({address_hash, params}) do
    address_hash
    |> String.downcase()
    |> Token.token_by_contract_address_hash_query()
    |> Repo.update_all(
      set: [
        fiat_value: params[:fiat_value],
        circulating_market_cap: params[:circulating_market_cap],
        volume_24h: params[:volume_24h],
        updated_at: DateTime.utc_now()
      ]
    )
  end

  defp schedule_first_fetching(state) do
    case state.source do
      Source.CoinGecko ->
        Process.send_after(self(), :fetch, state.interval)

      Source.Cryptorank ->
        Process.send_after(self(), :cryptorank_fetch, state.interval)
    end
  end
end
