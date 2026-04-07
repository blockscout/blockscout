defmodule Explorer.Market.Fetcher.Token do
  @moduledoc """
  Periodically fetches fiat value of tokens.
  """
  use GenServer, restart: :transient

  require Logger

  alias Ecto.Multi
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Hash.Address
  alias Explorer.Chain.Import.Runner.Tokens
  alias Explorer.Market.Source
  alias Explorer.MicroserviceInterfaces.MultichainSearch

  defstruct [
    :source,
    :source_state,
    :max_batch_size,
    :interval,
    :refetch_interval,
    seen_token_hashes: MapSet.new()
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
        filtered_tokens = Enum.reject(tokens_data, &Source.zero_or_nil?(&1[:fiat_value]))

        case update_tokens(filtered_tokens) do
          {:ok, _imported} ->
            enqueue_to_multichain(filtered_tokens)

          {:error, err} ->
            Logger.error("Error while importing tokens market data: #{inspect(err)}")

          {:error, step, failed_value, changes_so_far} ->
            Logger.error("Error while importing tokens market data: #{inspect({step, failed_value, changes_so_far})}")
        end

        new_seen =
          filtered_tokens
          |> Enum.reduce(state.seen_token_hashes, fn token, acc ->
            MapSet.put(acc, token.contract_address_hash)
          end)

        new_seen =
          if fetch_finished? do
            nullify_stale_market_data(new_seen)
            Process.send_after(self(), {:fetch, 0}, refetch_interval)
            MapSet.new()
          else
            Process.send_after(self(), {:fetch, 0}, interval)
            new_seen
          end

        {:noreply, %{state | source_state: source_state, seen_token_hashes: new_seen}}

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

  # Adds market data of the token (such as price and market cap) to the queue to send that to Multichain service.
  #
  # ## Parameters
  # - `tokens_data`: A list of token data.
  #
  # ## Returns
  # - `:ok` if the data is accepted for insertion.
  # - `:ignore` if the Multichain service is not used.
  @spec enqueue_to_multichain([
          %{
            :contract_address_hash => Address.t(),
            optional(:fiat_value) => Decimal.t(),
            optional(:circulating_market_cap) => Decimal.t(),
            optional(any()) => any()
          }
        ]) :: :ok | :ignore
  defp enqueue_to_multichain(tokens_data) do
    tokens_data
    |> Enum.reduce(%{}, fn token, acc ->
      data_for_multichain = MultichainSearch.prepare_token_market_data_for_queue(token)

      if data_for_multichain == %{} do
        acc
      else
        Map.put(acc, token.contract_address_hash.bytes, data_for_multichain)
      end
    end)
    |> MultichainSearch.send_token_info_to_queue(:market_data)
  end

  defp nullify_stale_market_data(seen_token_hashes) do
    if MapSet.size(seen_token_hashes) == 0 do
      :noop
    else
      do_nullify_stale_market_data(seen_token_hashes)
    end
  end

  defp do_nullify_stale_market_data(seen_token_hashes) do
    values_sql =
      seen_token_hashes
      |> Enum.map_join(",", fn hash -> "('\\x#{Base.encode16(hash.bytes, case: :lower)}')" end)

    Multi.new()
    |> Multi.run(:create_temp_table, fn repo, _changes ->
      repo.query("""
      CREATE TEMP TABLE temp_seen_token_hashes (
        contract_address_hash bytea
      ) ON COMMIT DROP
      """)
    end)
    |> Multi.run(:insert_seen_hashes, fn repo, _changes ->
      repo.query("INSERT INTO temp_seen_token_hashes VALUES #{values_sql}")
    end)
    |> Multi.run(:nullify_stale, fn repo, _changes ->
      repo.query("""
      UPDATE tokens
      SET fiat_value = NULL,
          circulating_market_cap = NULL,
          volume_24h = NULL,
          updated_at = NOW()
      WHERE fiat_value IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM temp_seen_token_hashes t
          WHERE t.contract_address_hash = tokens.contract_address_hash
        )
      """)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, step, reason, _} ->
        Logger.error("Failed to nullify stale market data at step #{step}: #{inspect(reason)}")
        :error
    end
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
