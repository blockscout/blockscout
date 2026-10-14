# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.RateLimit.Hammer.ETS do
  @moduledoc false
  use Hammer, backend: Hammer.ETS
end

defmodule BlockScoutWeb.RateLimit.Hammer.Redis do
  @moduledoc false
  # Bound every Redis call so that an unavailable Redis cannot block API requests
  # (the Hammer.Redis default is `:infinity`).
  use Hammer, backend: Hammer.Redis, timeout: 200
end

defmodule BlockScoutWeb.RateLimit.Hammer do
  @moduledoc """
    Wrapper for the rate limit functions. Defines union of all functions from `BlockScoutWeb.RateLimit.Hammer.ETS` and `BlockScoutWeb.RateLimit.Hammer.Redis`. Resolves the backend to use based on `Application.get_env(:block_scout_web, :rate_limit_backend)` in runtime.

    When the Redis backend is configured but Redis is unavailable, calls fall back to the
    ETS backend, so rate limiting keeps working per node instead of failing the request.
  """

  alias BlockScoutWeb.RateLimit.Hammer.{ETS, Redis}
  alias Explorer.Helper

  functions =
    (ETS.__info__(:functions) ++ Redis.__info__(:functions))
    |> Enum.uniq()

  for {name, arity} <- functions do
    args = Macro.generate_arguments(arity, nil)

    def unquote(name)(unquote_splicing(args)) do
      Helper.call_with_ets_fallback(
        Application.get_env(:block_scout_web, :api_rate_limit)[:rate_limit_backend],
        Redis,
        ETS,
        unquote(name),
        unquote(args)
      )
    end
  end

  def child_for_supervisor do
    config = Application.get_env(:block_scout_web, :api_rate_limit)

    if config[:redis_url] || config[:redis_sentinel_urls] do
      [
        {BlockScoutWeb.RateLimit.Hammer.Redis,
         Helper.redix_opts(
           config[:redis_url],
           config[:redis_ssl],
           config[:redis_sentinel_urls],
           config[:redis_sentinel_master_name]
         )},
        # Started alongside Redis so that it can be used as a fallback when Redis is unavailable
        {BlockScoutWeb.RateLimit.Hammer.ETS, []}
      ]
    else
      [{BlockScoutWeb.RateLimit.Hammer.ETS, []}]
    end
  end
end
