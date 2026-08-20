# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenUIMultiplierUpdater do
  @moduledoc """
  Records the [ERC-8056](https://eips.ethereum.org/EIPS/eip-8056) multiplier
  changes announced by `UIMultiplierUpdated` logs.

  Each change is written to `Explorer.Chain.Token.UIMultiplierChange`, so that
  amounts of past token transfers can be displayed with the multiplier that was
  in force back then, and the token itself is refreshed to carry the multiplier
  in force now.

  The standard requires the event on every change of the multiplier, so it is
  the only trigger needed: a change is always announced by a log, and the moment
  a scheduled change matures is derived from the recorded values rather than
  polled for.

  The history rows come from the log alone — all three parameters of the event
  are non-indexed — while the token itself is refreshed by reading the getters,
  which keeps it correct even if a log is missed or replaced by a reorg.
  """

  use GenServer

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.Chain.{Hash, Token}
  alias Explorer.Chain.Token.UIMultiplierChange
  alias Explorer.Token.MetadataRetriever
  alias Timex.Duration

  @default_update_interval :timer.seconds(10)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    schedule_next_update()

    {:ok, []}
  end

  @doc """
  Schedules the given ERC-8056 multiplier changes, as parsed by `Explorer.Chain.Token.ScaledUIAmount.parse_ui_multiplier_updated/1`, to be recorded.
  """
  @spec add_changes([map()]) :: :ok
  def add_changes([]), do: :ok

  def add_changes(changes) do
    GenServer.cast(__MODULE__, {:add_changes, changes})
  end

  @impl GenServer
  def handle_cast({:add_changes, changes}, state) do
    {:noreply, Enum.uniq(List.wrap(changes) ++ state)}
  end

  @impl GenServer
  def handle_info(:update, changes) do
    postponed =
      changes
      |> Enum.group_by(& &1.token_contract_address_hash)
      |> Enum.flat_map(fn {contract_address_hash, token_changes} ->
        case update_token(contract_address_hash, token_changes) do
          :ok -> []
          {:retry, retried_changes} -> retried_changes
        end
      end)

    schedule_next_update()

    {:noreply, postponed}
  end

  defp schedule_next_update do
    update_interval =
      case AverageBlockTime.average_block_time() do
        {:error, :disabled} -> @default_update_interval
        block_time -> round(Duration.to_milliseconds(block_time))
      end

    Process.send_after(self(), :update, update_interval)
  end

  @spec update_token(String.t(), [map()]) :: :ok | {:retry, [map()]}
  defp update_token(contract_address_hash, changes) do
    case Chain.string_to_address_hash(contract_address_hash) do
      {:ok, address_hash} ->
        address_hash
        |> then(&Repo.get_by(Token, contract_address_hash: &1))
        |> record_changes(address_hash, changes)

      _ ->
        :ok
    end
  end

  defp record_changes(nil, _address_hash, changes), do: {:retry, changes}

  defp record_changes(%Token{} = token, address_hash, changes) do
    if scaled_ui_amount_token?(token, address_hash) do
      changes
      |> Enum.map(&Map.put(&1, :token_contract_address_hash, address_hash))
      |> UIMultiplierChange.insert_changes()

      unless token.skip_metadata, do: refresh_token(token, address_hash)
    end

    :ok
  end

  defp scaled_ui_amount_token?(%Token{type: "ERC-8056"}, _address_hash), do: true

  defp scaled_ui_amount_token?(_token, address_hash) do
    address_hash |> Hash.to_string() |> MetadataRetriever.supports_scaled_ui_amount?()
  end

  defp refresh_token(token, address_hash) do
    token_params = address_hash |> Hash.to_string() |> MetadataRetriever.get_ui_multiplier_of()

    {:ok, _} = Token.update(token, Map.put(token_params, :type, "ERC-8056"))
  end
end
