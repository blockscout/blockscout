# SPDX-License-Identifier: LicenseRef-Blockscout

defmodule Explorer.Wallet.Balance do
  @moduledoc """
  Balance tracking for wallet accounts.

  Handles fetching and caching balances for ETH and ERC-20 tokens.
  """

  use Explorer.Chain.MapCache, key: :balance, ttl: 60
  require Logger

  alias Explorer.Chain
  alias Explorer.EthereumJsonrpc
  alias EthereumJsonrpc.Blocks

  @doc """
  Get balance for a wallet address.

  ## Parameters
    - address: Wallet address
    - chain_id: Blockchain network ID
    - token_contract: Optional token contract address (nil for native currency)

  ## Returns
    - Balance in Wei (for native currency) or token units
  """
  def get_balance(address, chain_id, token_contract \\ nil) do
    cache_key = cache_key(address, chain_id, token_contract)

    case fetch(cache_key) do
      {:ok, balance} ->
        {:ok, balance}

      :error ->
        fetch_balance(address, chain_id, token_contract)
    end
  end

  @doc """
  Get ETH balance for an address.
  """
  def get_eth_balance(address, chain_id) do
    get_balance(address, chain_id, nil)
  end

  @doc """
  Get token balance for an address.
  """
  def get_token_balance(address, chain_id, token_contract) do
    get_balance(address, chain_id, token_contract)
  end

  @doc """
  Invalidate balance cache for an address.
  """
  def invalidate_cache(address, chain_id, token_contract \\ nil) do
    cache_key = cache_key(address, chain_id, token_contract)
    ConCache.delete(:balance, cache_key)
  end

  # MapCache callbacks

  @impl Explorer.Chain.MapCache
  def handle_fallback(cache_key) do
    {address, chain_id, token_contract} = parse_cache_key(cache_key)
    fetch_balance(address, chain_id, token_contract)
  end

  # Private functions

  defp cache_key(address, chain_id, token_contract) do
    {address, chain_id, token_contract}
  end

  defp parse_cache_key({address, chain_id, token_contract}) do
    {address, chain_id, token_contract}
  end

  defp fetch_balance(address, _chain_id, nil) do
    # Fetch ETH balance
    case EthereumJsonrpc.json_rpc([
           %{
             id: 1,
             jsonrpc: "2.0",
             method: "eth_getBalance",
             params: [address, "latest"]
           }
         ]) do
      {:ok, [%{"result" => balance}]} ->
        {:ok, String.to_integer(balance, 16)}

      {:error, reason} ->
        Logger.error("Failed to fetch ETH balance for #{address}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_balance(address, _chain_id, token_contract) do
    # Fetch ERC-20 token balance using balanceOf call
    # TODO: Implement ERC-20 balance call via contract ABI
    {:ok, 0}
  end
end
