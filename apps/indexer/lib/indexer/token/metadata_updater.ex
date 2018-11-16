defmodule Indexer.Token.MetadataUpdater do
  @moduledoc """
  Updates metadata for cataloged tokens
  """

  use GenServer

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Explorer.Token.MetadataRetriever

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(state) do
    send(self(), :update_tokens)

    {:ok, state}
  end

  @impl true
  def handle_info(:update_tokens, state) do
    {:ok, tokens} = Chain.stream_cataloged_token_contract_address_hashes([], &(&2 ++ [&1]))
    update_metadata(tokens)

    interval = Application.get_env(:indexer, :metadata_updater_days_interval)
    Process.send_after(self(), :update_tokens, :timer.hours(interval) * 24)

    {:noreply, state}
  end

  @doc false
  def update_metadata(token_addresses) when is_list(token_addresses) do
    Enum.each(token_addresses, fn address ->
      case Chain.token_from_address_hash(address) do
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
