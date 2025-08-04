defmodule Explorer.Chain.SmartContract.Proxy.ResolverBehaviour do
  @moduledoc """
  Behaviour for smart contract proxy resolvers
  """

  alias Explorer.Chain.{Address, Hash}

  @type fetch_requirement :: {:storage | :call, String.t()}
  @type fetch_requirements :: %{atom() => fetch_requirement()}
  @type fetched_values :: %{atom() => String.t() | nil}

  @optional_callbacks resolve_implementations: 3

  @doc """
  Tries to immediately resolve implementations for the given proxy address and type,
  e.g., when proxy matches the well-known bytecode pattern, so there is no ambiguity.

  For other proxy types, returns a list of fetch requirements that need to be fetched
  before calling resolve_implementations, or nil if proxy type should not be resolved further.

  ## Parameters
  - `proxy_address`: The address of the proxy contract.
  - `proxy_type`: The type of the proxy contract.

  ## Returns
  - `{:ok, [Hash.Address.t()]}` if proxy implementations are resolved immediately without ambiguity.
  - `{:cont, fetch_requirements()}` if implementations cannot be resolved immediately,
    caller should fetch given requirements and call resolve_implementations.
  - `:error` if proxy resolution failed.
  - `nil` if proxy pattern does not match and no further resolution for this type is necessary.
  """
  @callback quick_resolve_implementations(proxy_address :: Address.t(), proxy_type :: atom()) ::
              {:ok, [Hash.Address.t()]} | {:cont, fetch_requirements()} | :error | nil

  @doc """
  Resolves implementations for the given proxy address and type.

  ## Parameters
  - `proxy_address`: The address of the proxy contract.
  - `proxy_type`: The type of the proxy contract.
  - `prefetched_values`: The values that were fetched in advance, according
    to the fetch requirements returned by quick_resolve_implementations.

  ## Returns
  - `{:ok, [Address.t()]}` if implementations are resolved.
  - `:error` if resolution failed.
  - `nil` if proxy pattern does not match.
  """
  @callback resolve_implementations(
              proxy_address :: Address.t(),
              proxy_type :: atom(),
              prefetched_values :: fetched_values()
            ) ::
              {:ok, [Hash.Address.t()]} | :error | nil
end
