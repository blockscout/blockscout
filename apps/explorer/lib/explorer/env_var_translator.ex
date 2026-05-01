defmodule Explorer.EnvVarTranslator do
  @moduledoc """
  The module for transformation of environment variables
  """

  @spec map_array_env_var_to_list(atom()) :: list()
  def map_array_env_var_to_list(config_name) do
    env_var = Application.get_env(:block_scout_web, config_name)

    if env_var do
      try do
        env_var
        |> Utils.JSON.decode!(keys: :atoms)
      rescue
        _ ->
          []
      end
    else
      []
    end
  end
end
