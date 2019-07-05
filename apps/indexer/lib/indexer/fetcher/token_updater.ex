defmodule Indexer.Fetcher.TokenUpdater do
  @moduledoc """
  Updates metadata for cataloged tokens
  """

  use GenServer
  use Indexer.Fetcher

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Explorer.Token.MetadataRetriever

  def start_link([initial_state, gen_server_options]) do
    GenServer.start_link(__MODULE__, initial_state, gen_server_options)
  end

  @impl true
  def init(state) do
    send(self(), :update_tokens)

    {:ok, state}
  end

  @impl true
  def handle_info(:update_tokens, state) do
    {:ok, tokens} = Chain.stream_cataloged_token_contract_address_hashes([], &[&1 | &2])

    tokens
    |> Enum.reverse()
    |> update_metadata()

    Process.send_after(self(), :update_tokens, :timer.seconds(state.update_interval))

    {:noreply, state}
  end

  @doc false
  def update_metadata(token_addresses) when is_list(token_addresses) do
    Enum.each(token_addresses, fn address ->
      case Chain.token_from_address_hash(address, [{:contract_address, :smart_contract}]) do
        {:ok, %Token{cataloged: true} = token} ->
          update_metadata(token)
      end
    end)
  end

  def update_metadata(%Token{contract_address_hash: contract_address_hash} = token) do
    contract_functions = MetadataRetriever.get_functions_of(contract_address_hash)

    Chain.update_token(%{token | updated_at: DateTime.utc_now()}, contract_functions)
  end
end
