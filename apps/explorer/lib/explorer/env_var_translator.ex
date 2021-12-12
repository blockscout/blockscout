defmodule Explorer.EnvVarTranslator do
  @moduledoc """
  The module for transaformation of environment variables
  """

  alias Poison.Parser

  @spec map_array_env_var_to_list(Atom.t()) :: List.t()
  def map_array_env_var_to_list(config_name) do
    env_var = Application.get_env(:block_scout_web, config_name)

    if env_var do
      try do
        env_var
        |> Parser.parse!(%{keys: :atoms!})
      rescue
        _ ->
          []
      end
    else
      []
    end
  end
end
