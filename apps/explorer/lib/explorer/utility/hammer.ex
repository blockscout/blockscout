# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.Hammer.ETS do
  @moduledoc false
  use Hammer, backend: Hammer.ETS
end

defmodule Explorer.Utility.Hammer.Redis do
  @moduledoc false
  # Bound every Redis call so that an unavailable Redis cannot block callers
  # (the Hammer.Redis default is `:infinity`).
  use Hammer, backend: Hammer.Redis, timeout: 200
end

defmodule Explorer.Utility.Hammer do
  @moduledoc """
    Wrapper for the rate limit functions. Defines union of all functions from `Explorer.Utility.Hammer.ETS` and `Explorer.Utility.Hammer.Redis`. Resolves the backend to use based on `Application.get_env(:explorer, Explorer.Utility.RateLimiter)[:hammer_backend_module]` in runtime.

    When the Redis backend is configured but Redis is unavailable, calls fall back to the
    ETS backend, so rate limiting keeps working per node instead of failing the caller.
  """

  alias Explorer.Helper
  alias Explorer.Utility.Hammer.{ETS, Redis}

  functions =
    (ETS.__info__(:functions) ++ Redis.__info__(:functions))
    |> Enum.uniq()

  for {name, arity} <- functions do
    args = Macro.generate_arguments(arity, nil)

    def unquote(name)(unquote_splicing(args)) do
      Helper.call_with_ets_fallback(
        Application.get_env(:explorer, Explorer.Utility.RateLimiter)[:hammer_backend_module],
        Redis,
        ETS,
        unquote(name),
        unquote(args)
      )
    end
  end

  def child_for_supervisor do
    config = Application.get_env(:explorer, Explorer.Utility.RateLimiter)

    case config[:storage] do
      :redis ->
        {Explorer.Utility.Hammer.Redis,
         Helper.redix_opts(
           config[:redis_url],
           config[:redis_ssl],
           config[:redis_sentinel_urls],
           config[:redis_sentinel_master_name]
         )}

      :ets ->
        {Explorer.Utility.Hammer.ETS, []}
    end
  end

  @doc """
  Returns the ETS backend child spec to start alongside the Redis backend, so that
  it can be used as a fallback when Redis is unavailable. Returns `[]` when the ETS
  backend is already the configured one.
  """
  @spec fallback_child_for_supervisor() :: {module(), keyword()} | []
  def fallback_child_for_supervisor do
    case Application.get_env(:explorer, Explorer.Utility.RateLimiter)[:storage] do
      :redis -> {Explorer.Utility.Hammer.ETS, []}
      :ets -> []
    end
  end
end
