defmodule Explorer.Market.Fetcher.Token do
  @moduledoc """
  Periodically fetches fiat value of tokens.
  """
  use GenServer, restart: :transient

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Import.Runner.Tokens
  alias Explorer.Market.Source

  defstruct [
    :source,
    :source_state,
    :max_batch_size,
    :interval,
    :refetch_interval
  ]

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    case Source.tokens_source() do
      source when not is_nil(source) ->
        state =
          %__MODULE__{
            source: source,
            max_batch_size: config(:max_batch_size),
            interval: config(:interval),
            refetch_interval: config(:refetch_interval)
          }

        Process.send_after(self(), {:fetch, 0}, state.interval)

        {:ok, state}

      nil ->
        Logger.info("Token exchange rates source is not configured")
        :ignore
    end
  end

  @impl GenServer
  def handle_info(
        {:fetch, attempt},
        %__MODULE__{
          source: source,
          source_state: source_state,
          max_batch_size: max_batch_size,
          interval: interval,
          refetch_interval: refetch_interval
        } = state
      ) do
    case source.fetch_tokens(source_state, max_batch_size) do
      {:ok, source_state, fetch_finished?, tokens_data} ->
        case update_tokens(tokens_data) do
          {:ok, _imported} ->
            :ok

          {:error, err} ->
            Logger.error("Error while importing tokens market data: #{inspect(err)}")

          {:error, step, failed_value, changes_so_far} ->
            Logger.error("Error while importing tokens market data: #{inspect({step, failed_value, changes_so_far})}")
        end

        if fetch_finished? do
          Process.send_after(self(), {:fetch, 0}, refetch_interval)
        else
          Process.send_after(self(), {:fetch, 0}, interval)
        end

        {:noreply, %{state | source_state: source_state}}

      {:error, reason} ->
        Logger.error("Error while fetching tokens: #{inspect(reason)}")

        if attempt < 5 do
          Process.send_after(self(), {:fetch, attempt + 1}, :timer.seconds(attempt ** 5))
          {:noreply, state}
        else
          Process.send_after(self(), {:fetch, 0}, refetch_interval)
          {:noreply, %{state | source_state: nil}}
        end

      :ignore ->
        Logger.warning("Tokens fetching not implemented for selected source: #{source}")
        {:stop, :shutdown, state}
    end
  end

  @impl GenServer
  def handle_info({_ref, _result}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  defp update_tokens(token_params) do
    Chain.import(%{
      tokens: %{
        params: token_params,
        on_conflict: Tokens.market_data_on_conflict(),
        fields_to_update: Tokens.market_data_fields_to_update()
      }
    })
  end

  defp config(key) do
    Application.get_env(:explorer, __MODULE__)[key]
  end
end
