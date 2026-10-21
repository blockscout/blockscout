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

  require Logger

  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.Chain.{Hash, Token}
  alias Explorer.Chain.Token.UIMultiplierChange
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.Repo
  alias Explorer.Token.MetadataRetriever
  alias Timex.Duration

  @default_update_interval :timer.seconds(10)

  @max_attempts 10

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    schedule_next_update()

    {:ok, %{}}
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
    {:noreply, changes |> List.wrap() |> Enum.reduce(state, &Map.put_new(&2, &1, 0))}
  end

  @impl GenServer
  def handle_info(:update, state) do
    postponed =
      state
      |> Map.keys()
      |> Enum.group_by(& &1.token_contract_address_hash)
      |> Enum.flat_map(fn {contract_address_hash, token_changes} ->
        case update_token(contract_address_hash, token_changes) do
          :ok -> []
          {:retry, retried_changes} -> retried_changes
        end
      end)
      |> Enum.reduce(%{}, &postpone(&1, &2, state))

    schedule_next_update()

    {:noreply, postponed}
  end

  defp postpone(change, postponed, state) do
    case Map.get(state, change, 0) + 1 do
      attempts when attempts < @max_attempts ->
        Map.put(postponed, change, attempts)

      _ ->
        Logger.warning(fn ->
          "Dropping ERC-8056 multiplier change of #{change.token_contract_address_hash}: " <>
            "the token is still not indexed after #{@max_attempts} attempts"
        end)

        postponed
    end
  end

  defp schedule_next_update do
    update_interval =
      case AverageBlockTime.average_block_time() do
        {:error, :disabled} -> @default_update_interval
        block_time -> round(Duration.to_milliseconds(block_time))
      end

    Process.send_after(self(), :update, update_interval)
  end

  # the hash comes off the log, so it is the string the node answered with, but
  # `Hash.Address.cast/1` takes an already cast struct just as well and keeps a
  # producer that hands one over from being dropped silently
  @spec update_token(String.t() | Hash.Address.t(), [map()]) :: :ok | {:retry, [map()]}
  defp update_token(contract_address_hash, changes) do
    case Hash.Address.cast(contract_address_hash) do
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
    case scaled_ui_amount_support(token, address_hash) do
      {:ok, true} ->
        changes
        |> Enum.map(&Map.put(&1, :token_contract_address_hash, address_hash))
        |> UIMultiplierChange.insert_changes()

        unless token.skip_metadata, do: refresh_token(token, address_hash)

        :ok

      {:ok, false} ->
        :ok

      :error ->
        {:retry, changes}
    end
  end

  defp scaled_ui_amount_support(%Token{type: "ERC-8056"}, _address_hash), do: {:ok, true}

  defp scaled_ui_amount_support(_token, address_hash) do
    address_hash |> Hash.to_string() |> MetadataRetriever.scaled_ui_amount_support()
  end

  defp refresh_token(token, address_hash) do
    token_params = address_hash |> Hash.to_string() |> MetadataRetriever.get_ui_multiplier_of()

    case Token.update(token, Map.put(token_params, :type, "ERC-8056")) do
      {:ok, updated_token} ->
        # the multiplier is part of the token metadata exported to the Multichain service,
        # so the whole metadata entry is re-sent with the values in force now
        %{address_hash => MultichainSearch.prepare_token_metadata_for_queue(updated_token)}
        |> MultichainSearch.send_token_info_to_queue(:metadata)

        :ok

      {:error, changeset} ->
        Logger.error(fn ->
          "Failed to update ERC-8056 token #{address_hash}: #{inspect(changeset.errors)}"
        end)

        :ok
    end
  end
end
