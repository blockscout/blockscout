defmodule Indexer.Fetcher.TokenTotalSupplyOnDemand do
  @moduledoc """
    Ensures that we have a reasonably up to date token supply.
  """

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Token
  alias Explorer.Token.MetadataRetriever

  @ttl_in_blocks 1

  ## Interface

  @spec trigger_fetch(Chain.Hash.Address.t()) :: :ok
  def trigger_fetch(address) do
    GenServer.cast(__MODULE__, {:fetch_and_update, address})
  end

  ## Callbacks

  def start_link([init_opts, server_opts]) do
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl true
  def init(init_arg) do
    {:ok, init_arg}
  end

  @impl true
  def handle_cast({:fetch_and_update, address}, state) do
    do_fetch(address)

    {:noreply, state}
  end

  ## Implementation

  defp do_fetch(address) when not is_nil(address) do
    token =
      Token
      |> Repo.get_by(contract_address_hash: address)
      |> Repo.preload([:contract_address])

    if is_nil(token.total_supply_updated_at_block) or
         BlockNumber.get_max() - token.total_supply_updated_at_block > @ttl_in_blocks do
      token_address_hash = "0x" <> Base.encode16(address.bytes)

      token_params =
        token_address_hash
        |> MetadataRetriever.get_total_supply_of()

      {:ok, token} =
        Chain.update_token(token, Map.put(token_params, :total_supply_updated_at_block, BlockNumber.get_max()))

      Publisher.broadcast(%{token_total_supply: [token]}, :on_demand)
      :ok
    end
  end
end
