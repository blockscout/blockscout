# SPDX-License-Identifier: LicenseRef-Blockscout
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
        |> Utils.JSON.decode!()
        |> atomize_new_tag_entries()
      rescue
        _ ->
          []
      end
    else
      []
    end
  end

  defp atomize_new_tag_entries(entries) when is_list(entries) do
    Enum.map(entries, fn
      %{"tag" => tag, "title" => title} -> %{tag: tag, title: title}
      entry -> entry
    end)
  end
end
