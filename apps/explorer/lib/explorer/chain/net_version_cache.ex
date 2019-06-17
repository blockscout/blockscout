defmodule Explorer.Chain.NetVersionCache do
  @moduledoc """
  Caches chain version.
  """

  @cache_name :net_version
  @key :version

  @spec version() :: non_neg_integer() | {:error, any()}
  def version do
    cached_value = fetch_from_cache()

    if is_nil(cached_value) do
      fetch_from_node()
    else
      cached_value
    end
  end

  def cache_name do
    @cache_name
  end

  defp fetch_from_cache do
    ConCache.get(@cache_name, @key)
  end

  defp cache_value(value) do
    ConCache.put(@cache_name, @key, value)
  end

  defp fetch_from_node do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    case EthereumJSONRPC.fetch_net_version(json_rpc_named_arguments) do
      {:ok, value} ->
        cache_value(value)
        value

      other ->
        other
    end
  end
end
