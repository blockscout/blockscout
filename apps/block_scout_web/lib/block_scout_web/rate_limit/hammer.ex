defmodule BlockScoutWeb.RateLimit.Hammer.ETS do
  @moduledoc false
  use Hammer, backend: Hammer.ETS
end

defmodule BlockScoutWeb.RateLimit.Hammer.Redis do
  @moduledoc false
  use Hammer, backend: Hammer.Redis
end

defmodule BlockScoutWeb.RateLimit.Hammer do
  @moduledoc """
    Wrapper for the rate limit functions. Defines union of all functions from `BlockScoutWeb.RateLimit.Hammer.ETS` and `BlockScoutWeb.RateLimit.Hammer.Redis`. Resolves the backend to use based on `Application.get_env(:block_scout_web, :rate_limit_backend)` in runtime.
  """

  alias BlockScoutWeb.RateLimit.Hammer.{ETS, Redis}
  alias Explorer.Helper

  functions =
    (ETS.__info__(:functions) ++ Redis.__info__(:functions))
    |> Enum.uniq()

  for {name, arity} <- functions do
    args = Macro.generate_arguments(arity, nil)

    def unquote(name)(unquote_splicing(args)) do
      apply(Application.get_env(:block_scout_web, :api_rate_limit)[:rate_limit_backend], unquote(name), unquote(args))
    end
  end

  def child_for_supervisor do
    config = Application.get_env(:block_scout_web, :api_rate_limit)

    if config[:redis_url] || config[:redis_sentinel_urls] do
      {BlockScoutWeb.RateLimit.Hammer.Redis,
       Helper.redix_opts(
         config[:redis_url],
         config[:redis_ssl],
         config[:redis_sentinel_urls],
         config[:redis_sentinel_master_name]
       )}
    else
      {BlockScoutWeb.RateLimit.Hammer.ETS, []}
    end
  end
end
