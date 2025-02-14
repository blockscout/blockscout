defmodule Indexer.Fetcher.TokenTotalSupplyUpdater do
  @moduledoc """
  Periodically updates tokens total_supply
  """

  use GenServer

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.Chain.Token
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
    Enum.each(contract_address_hashes, &update_token/1)

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

  defp update_token(nil), do: :ok

  defp update_token(address_hash_string) do
    {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)

    token = Repo.get_by(Token, contract_address_hash: address_hash)

    if token && !token.skip_metadata do
      token_params = MetadataRetriever.get_total_supply_of(address_hash_string)

      if token_params !== %{} do
        {:ok, _} = Token.update(token, token_params)
      end
    end

    :ok
  end
end
