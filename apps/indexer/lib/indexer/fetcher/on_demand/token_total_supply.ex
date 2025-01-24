defmodule Indexer.Fetcher.OnDemand.TokenTotalSupply do
  @moduledoc """
    Ensures that we have a reasonably up to date token supply.
  """

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.{Hash, Token}
  alias Explorer.Repo
  alias Explorer.Token.MetadataRetriever

  @ttl_in_blocks 1

  ## Interface

  @spec trigger_fetch(Hash.Address.t()) :: :ok
  def trigger_fetch(address_hash) do
    GenServer.cast(__MODULE__, {:fetch_and_update, address_hash})
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
  def handle_cast({:fetch_and_update, address_hash}, state) do
    do_fetch(address_hash)

    {:noreply, state}
  end

  ## Implementation

  defp do_fetch(address_hash) when not is_nil(address_hash) do
    token = Repo.get_by(Token, contract_address_hash: address_hash)

    if (token && !token.skip_metadata && is_nil(token.total_supply_updated_at_block)) or
         BlockNumber.get_max() - token.total_supply_updated_at_block > @ttl_in_blocks do
      token_address_hash_string = "0x" <> Base.encode16(address_hash.bytes)

      token_params = MetadataRetriever.get_total_supply_of(token_address_hash_string)

      if token_params !== %{} do
        {:ok, token} = Token.update(token, token_params)

        Publisher.broadcast(%{token_total_supply: [token]}, :on_demand)
      end

      :ok
    end
  end
end
