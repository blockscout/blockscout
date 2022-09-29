defmodule Explorer.Account do
  @moduledoc """
  Context for Account module.
  """

  def enabled? do
    Application.get_env(:explorer, __MODULE__)[:enabled]
  end
end
