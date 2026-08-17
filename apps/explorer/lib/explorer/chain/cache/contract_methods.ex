# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.ContractMethods do
  @moduledoc """
  Cache for `Explorer.Chain.ContractMethod` lookups by method id and for ABI
  candidates returned by the sig-provider microservice.

  Candidates for a 4-byte selector change only when new methods are inserted on
  contract verification, so found entries are cached with a long TTL and empty
  results with a short one, keeping transaction input decoding off the DB and
  HTTP paths for hot method ids.
  """

  alias Explorer.Chain.ContractMethod

  @cache_name :contract_methods
  @found_ttl :timer.hours(1)
  @not_found_ttl :timer.minutes(5)

  @spec cache_name() :: atom()
  def cache_name, do: @cache_name

  @doc """
  Same as `Explorer.Chain.ContractMethod.find_contract_methods/2`, but serves
  repeated lookups from cache. Ids missing from the cache are fetched from the
  DB in a single query and cached, including ids with no known methods.
  """
  @spec find_contract_methods([Explorer.Chain.MethodIdentifier.t()], keyword()) :: [ContractMethod.t()]
  def find_contract_methods(method_ids, options) do
    if enabled?() do
      find_contract_methods_with_cache(method_ids, options)
    else
      ContractMethod.find_contract_methods(method_ids, options)
    end
  end

  @doc """
  Fetches the sig-provider ABI candidates for a method id, calling `fallback_fn`
  and caching its result (including an empty one) on a cache miss.
  """
  @spec fetch_sig_provider_abi(binary(), (-> [map()])) :: [map()]
  def fetch_sig_provider_abi(method_id, fallback_fn) when is_function(fallback_fn, 0) do
    if enabled?() do
      {:ok, abi} =
        ConCache.fetch_or_store(@cache_name, {:sig_provider_abi, method_id}, fn ->
          {:ok, item(fallback_fn.())}
        end)

      abi
    else
      fallback_fn.()
    end
  end

  defp find_contract_methods_with_cache(method_ids, options) do
    {cached_methods, missing_ids} =
      Enum.reduce(method_ids, {[], []}, fn method_id, {cached, missing} ->
        case ConCache.get(@cache_name, {:contract_method, method_id}) do
          nil -> {cached, [method_id | missing]}
          methods -> {methods ++ cached, missing}
        end
      end)

    fetched_methods = ContractMethod.find_contract_methods(missing_ids, options)
    fetched_by_id = Enum.group_by(fetched_methods, & &1.identifier)

    Enum.each(missing_ids, fn method_id ->
      methods = Map.get(fetched_by_id, method_id, [])
      ConCache.put(@cache_name, {:contract_method, method_id}, item(methods))
    end)

    cached_methods ++ fetched_methods
  end

  defp enabled? do
    Application.get_env(:explorer, __MODULE__)[:enabled]
  end

  defp item(value) do
    %ConCache.Item{value: value, ttl: if(value == [], do: @not_found_ttl, else: @found_ttl)}
  end
end
