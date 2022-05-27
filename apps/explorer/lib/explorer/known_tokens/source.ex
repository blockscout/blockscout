defmodule Explorer.KnownTokens.Source do
  @moduledoc """
  Behaviour for fetching list of known tokens.
  """

  alias Explorer.Chain.Hash
  alias Explorer.ExchangeRates.Source

  @doc """
  Fetches known tokens
  """
  @spec fetch_known_tokens() :: {:ok, [Hash.Address.t()]} | {:error, any}
  def fetch_known_tokens(source \\ known_tokens_source()) do
    Source.http_request(source.source_url(), source.headers())
  end

  @doc """
  Url for querying the list of known tokens.
  """
  @callback source_url() :: String.t()

  @spec known_tokens_source() :: module()
  defp known_tokens_source do
    config(:source) || Explorer.KnownTokens.Source.MyEtherWallet
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end
end
