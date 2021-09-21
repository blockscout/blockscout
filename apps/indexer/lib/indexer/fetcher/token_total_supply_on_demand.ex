defmodule Indexer.Fetcher.TokenTotalSupplyOnDemand do
  @moduledoc """
  Ensures that we have a reasonably up to date token supply.

  """

  use GenServer
  use Indexer.Fetcher

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Token}
  alias Explorer.Token.MetadataRetriever

  ## Interface

  @spec trigger_fetch(Address.t()) :: :ok
  def trigger_fetch(address) do
    do_trigger_fetch(address)
  end

  ## Callbacks

  def start_link([init_opts, server_opts]) do
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  ## Implementation

  defp do_trigger_fetch(address) when not is_nil(address) do
    token_address_hash = "0x" <> Base.encode16(address.bytes)

    token_params =
      token_address_hash
      |> MetadataRetriever.get_total_supply_of()

    token =
      Token
      |> Repo.get_by(contract_address_hash: address)
      |> Repo.preload([:contract_address])

    Chain.update_token(%{token | updated_at: DateTime.utc_now()}, token_params)
    :ok
  end
end
