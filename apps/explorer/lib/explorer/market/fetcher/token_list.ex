defmodule Explorer.Market.Fetcher.TokenList do
  @moduledoc """
  Periodically fetches a token list from a URL conforming to the
  [Token Lists](https://tokenlists.org/) standard and imports token
  metadata (icon, name, symbol, decimals) into the database.

  Enabled when `TOKEN_LIST_URL` environment variable is set.
  """
  use GenServer, restart: :transient

  use Utils.RuntimeEnvHelper,
    chain_id: [:explorer, :chain_id]

  alias Explorer.{Chain, HttpClient}
  alias Explorer.Chain.Import.Runner.Tokens

  require Logger

  defstruct [:url, :refetch_interval]

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    config = Application.get_env(:explorer, __MODULE__)
    url = config[:token_list_url]

    if url do
      state = %__MODULE__{
        url: url,
        refetch_interval: config[:refetch_interval] || :timer.hours(24)
      }

      send(self(), :fetch)

      {:ok, state}
    else
      :ignore
    end
  end

  @impl GenServer
  def handle_info(:fetch, %__MODULE__{url: url, refetch_interval: refetch_interval} = state) do
    case fetch_and_import(url) do
      {:ok, count} ->
        Logger.info("Token list: imported #{count} tokens from #{url}")

      {:error, reason} ->
        Logger.error("Token list: failed to fetch from #{url}: #{inspect(reason)}")
    end

    Process.send_after(self(), :fetch, refetch_interval)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_msg, state), do: {:noreply, state}

  defp fetch_and_import(url) do
    with {:ok, %{body: body, status_code: 200}} <- HttpClient.get(url),
         {:ok, %{"tokens" => tokens}} when is_list(tokens) <- Jason.decode(body) do
      token_params =
        tokens
        |> filter_by_chain_id()
        |> Enum.map(&to_token_params/1)
        |> Enum.reject(&is_nil/1)

      case import_tokens(token_params) do
        {:ok, _} -> {:ok, length(token_params)}
        {:error, _} = error -> error
        {:error, step, failed_value, _changes} -> {:error, {step, failed_value}}
      end
    else
      {:ok, %{status_code: status}} -> {:error, {:http_status, status}}
      {:error, _} = error -> error
    end
  end

  defp filter_by_chain_id(tokens) do
    case chain_id() do
      nil ->
        Logger.warning("Token list: CHAIN_ID is not set, importing all tokens from the list")
        tokens

      chain_id_string ->
        chain_id_int = String.to_integer(chain_id_string)
        Enum.filter(tokens, fn token -> token["chainId"] == chain_id_int end)
    end
  end

  defp to_token_params(%{"address" => address} = token) when is_binary(address) do
    %{
      contract_address_hash: address,
      name: token["name"],
      symbol: token["symbol"],
      decimals: token["decimals"],
      icon_url: token["logoURI"],
      type: "ERC-20"
    }
  end

  defp to_token_params(_), do: nil

  defp import_tokens([]), do: {:ok, %{}}

  defp import_tokens(token_params) do
    Chain.import(%{
      tokens: %{
        params: token_params,
        on_conflict: Tokens.token_list_on_conflict(),
        fields_to_update: Tokens.token_list_fields_to_update()
      }
    })
  end
end
