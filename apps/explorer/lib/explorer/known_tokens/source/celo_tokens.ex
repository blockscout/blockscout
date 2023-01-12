defmodule Explorer.KnownTokens.Source.CeloTokens do
  @moduledoc """
  Adapter for fetching known CELO tokens from Celo Explorer's GitHub
  """

  alias Explorer.KnownTokens.Source

  @behaviour Source

  @impl Source
  def source_url do
    "https://raw.githubusercontent.com/celo-org/blockscout/master/apps/ethereum_jsonrpc/priv/js/tokens/celoTokens.json"
  end

  @impl Source
  def headers do
    []
  end
end
