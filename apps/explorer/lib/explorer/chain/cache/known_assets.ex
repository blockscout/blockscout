# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.KnownAssets do
  @moduledoc """
  Keeps an index of the assets worth imitating — the accepted contracts per
  normalized token symbol and name — in an ETS table, for the
  `name_imitation` rule of the poisoning attack detection.

  An asset is known when the instance has reason to trust its contract: the
  token was verified through the admin panel, or it carries market data. The
  operator can add or extend assets through
  `TOKEN_TRANSFER_POISONING_KNOWN_ASSETS`; an entry there is unioned with what
  the database says, never replacing it.

  The table is rebuilt on an interval. Until the first build succeeds the
  index is reported as missing and the rule falls back to the operator's
  entries alone.
  """

  use GenServer

  require Logger

  import Ecto.Query, only: [select: 3, where: 3]

  alias Explorer.Chain.{Hash, Token}
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.{Config, Context, Rules}
  alias Explorer.Repo

  @cache_name :token_transfer_poisoning_known_assets
  @loaded_key :__loaded__

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  @spec init(any()) :: {:ok, nil}
  def init(_) do
    :ets.new(@cache_name, [:set, :named_table, :public, read_concurrency: true])

    send(self(), :reload)

    {:ok, nil}
  end

  @impl true
  def handle_info(:reload, state) do
    load()
    Process.send_after(self(), :reload, Config.load().known_assets_update_interval)

    {:noreply, state}
  end

  @impl true
  def handle_call(:reload, _from, state) do
    load()

    {:reply, :ok, state}
  end

  @doc """
  The index, or `nil` while it has not been built.
  """
  @spec index() :: Context.known_assets() | nil
  def index do
    if loaded?() do
      [{@loaded_key, index}] = :ets.lookup(@cache_name, @loaded_key)
      index
    else
      nil
    end
  end

  @doc """
  Rebuilds the index now rather than on the next interval.
  """
  @spec reload() :: :ok
  def reload do
    GenServer.call(__MODULE__, :reload)
  catch
    :exit, _ -> :ok
  end

  @doc """
  Builds the index from the database and the operator's `known_assets_override`.
  """
  @spec build_index(%{String.t() => [Hash.Address.t()]}) :: Context.known_assets()
  def build_index(override) do
    db_index = known_tokens_query() |> Repo.all() |> index_from_tokens()

    %{
      symbols: merge_override(db_index.symbols, override),
      names: merge_override(db_index.names, override)
    }
  end

  @doc """
  The index made of the operator's entries alone, for when the cache has not
  been built.
  """
  @spec index_from_override(%{String.t() => [Hash.Address.t()]}) :: Context.known_assets()
  def index_from_override(override) do
    sets = Map.new(override, fn {key, contracts} -> {key, MapSet.new(contracts)} end)

    %{symbols: sets, names: sets}
  end

  defp load do
    index = build_index(Config.load().known_assets_override)
    :ets.insert(@cache_name, {@loaded_key, index})

    :ok
  rescue
    error ->
      Logger.error("Failed to build the known assets index: #{inspect(error)}")

      :ok
  end

  defp known_tokens_query do
    Token
    |> where(
      [token],
      token.is_verified_via_admin_panel == true or not is_nil(token.fiat_value) or
        not is_nil(token.circulating_market_cap)
    )
    |> where([token], not is_nil(token.symbol) or not is_nil(token.name))
    |> select([token], {token.contract_address_hash, token.symbol, token.name})
  end

  defp index_from_tokens(tokens) do
    Enum.reduce(tokens, %{symbols: %{}, names: %{}}, fn {contract, symbol, name}, acc ->
      acc
      |> put_asset(:symbols, Rules.normalize_asset_name(symbol), contract)
      |> put_asset(:names, Rules.normalize_asset_name(name), contract)
    end)
  end

  defp put_asset(index, _field, nil, _contract), do: index

  defp put_asset(index, field, key, contract) do
    Map.update!(index, field, fn assets ->
      Map.update(assets, key, MapSet.new([contract]), &MapSet.put(&1, contract))
    end)
  end

  defp merge_override(assets, override) do
    Enum.reduce(override, assets, fn {key, contracts}, acc ->
      Map.update(acc, key, MapSet.new(contracts), &MapSet.union(&1, MapSet.new(contracts)))
    end)
  end

  defp loaded? do
    :ets.whereis(@cache_name) != :undefined and :ets.member(@cache_name, @loaded_key)
  end
end
