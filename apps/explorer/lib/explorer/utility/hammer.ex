defmodule Explorer.Utility.Hammer.ETS do
  @moduledoc false
  use Hammer, backend: Hammer.ETS
end

defmodule Explorer.Utility.Hammer.Redis do
  @moduledoc false
  use Hammer, backend: Hammer.Redis
end

defmodule Explorer.Utility.Hammer do
  @moduledoc """
    Wrapper for the rate limit functions. Defines union of all functions from `Explorer.Utility.Hammer.ETS` and `Explorer.Utility.Hammer.Redis`. Resolves the backend to use based on `Application.get_env(:explorer, Explorer.Utility.RateLimiter)[:hammer_backend_module]` in runtime.
  """
  alias Explorer.Utility.Hammer.{ETS, Redis}

  functions =
    (ETS.__info__(:functions) ++ Redis.__info__(:functions))
    |> Enum.uniq()

  for {name, arity} <- functions do
    args = Macro.generate_arguments(arity, nil)

    def unquote(name)(unquote_splicing(args)) do
      apply(
        Application.get_env(:explorer, Explorer.Utility.RateLimiter)[:hammer_backend_module],
        unquote(name),
        unquote(args)
      )
    end
  end

  def child_for_supervisor do
    config = Application.get_env(:explorer, Explorer.Utility.RateLimiter)

    case config[:storage] do
      :redis -> {Explorer.Utility.Hammer.Redis, [url: config[:redis_url]]}
      :ets -> {Explorer.Utility.Hammer.ETS, []}
    end
  end
end
