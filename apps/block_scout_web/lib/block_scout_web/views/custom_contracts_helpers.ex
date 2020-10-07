defmodule BlockScoutWeb.CustomContractsHelpers do
  @moduledoc """
  Helpers to enable custom contracts themes
  """

  def get_dark_forest_addresses_list do
    dark_forest_addresses_var = get_raw_dark_forest_addresses_list()
    dark_forest_addresses_list = (dark_forest_addresses_var && String.split(dark_forest_addresses_var, ",")) || []

    formatted_dark_forest_addresses_list =
      dark_forest_addresses_list
      |> Enum.map(fn addr ->
        String.downcase(addr)
      end)

    formatted_dark_forest_addresses_list
  end

  def get_raw_dark_forest_addresses_list do
    Application.get_env(:block_scout_web, :dark_forest_addresses)
  end
end
