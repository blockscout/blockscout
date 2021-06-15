defmodule BlockScoutWeb.CustomContractsHelpers do
  @moduledoc """
  Helpers to enable custom contracts themes
  """

  def get_custom_addresses_list(env_var) do
    addresses_var = get_raw_custom_addresses_list(env_var)
    addresses_list = (addresses_var && String.split(addresses_var, ",")) || []

    formatted_addresses_list =
      addresses_list
      |> Enum.map(fn addr ->
        String.downcase(addr)
      end)

    formatted_addresses_list
  end

  def get_raw_custom_addresses_list(env_var) do
    Application.get_env(:block_scout_web, env_var)
  end
end
