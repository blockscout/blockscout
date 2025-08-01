defmodule Indexer.Fetcher.TokenTotalSupplyUpdater do
  @moduledoc """
  Periodically updates tokens total_supply
  """

  use GenServer

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.Chain.{Hash, Token}
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.Token.MetadataRetriever
  alias Timex.Duration

  @default_update_interval :timer.seconds(10)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    schedule_next_update()

    {:ok, []}
  end

  def add_tokens(contract_address_hashes) do
    GenServer.cast(__MODULE__, {:add_tokens, contract_address_hashes})
  end

  def handle_cast({:add_tokens, contract_address_hashes}, state) do
    {:noreply, Enum.uniq(List.wrap(contract_address_hashes) ++ state)}
  end

  def handle_info(:update, contract_address_hashes) do
    contract_address_hashes
    |> Enum.reduce(%{}, fn contract_address_hash, acc ->
      with {:ok, address_hash} <- Chain.string_to_address_hash(contract_address_hash),
           data_for_multichain = update_token(address_hash),
           false <- is_nil(data_for_multichain) do
        Map.put(acc, address_hash.bytes, data_for_multichain)
      else
        _ -> acc
      end
    end)
    |> MultichainSearch.send_token_info_to_queue(:total_supply)

    schedule_next_update()

    {:noreply, []}
  end

  defp schedule_next_update do
    update_interval =
      case AverageBlockTime.average_block_time() do
        {:error, :disabled} -> @default_update_interval
        block_time -> round(Duration.to_milliseconds(block_time))
      end

    Process.send_after(self(), :update, update_interval)
  end

  defp update_token(address_hash) do
    token = Repo.get_by(Token, contract_address_hash: address_hash)

    if token && !token.skip_metadata do
      token_params =
        address_hash
        |> Hash.to_string()
        |> MetadataRetriever.get_total_supply_of()

      if token_params !== %{} do
        {:ok, _} = Token.update(token, token_params)

        MultichainSearch.prepare_token_total_supply_for_queue(token_params.total_supply)
      end
    end
  end
end
