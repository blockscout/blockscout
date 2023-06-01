defmodule BlockScoutWeb.API.V2 do
  @moduledoc """
    API V2 context
  """

  def enabled? do
    Application.get_env(:block_scout_web, __MODULE__)[:enabled]
  end
end
