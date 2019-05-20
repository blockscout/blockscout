defmodule BlockScoutWeb.PaginationHelpers do
  @moduledoc """
    Common pagination logic helpers.
  """

  def current_page_number(params) do
    cond do
      !params["prev_page_number"] -> 1
      params["next_page"] -> String.to_integer(params["prev_page_number"]) + 1
      params["prev_page"] -> String.to_integer(params["prev_page_number"]) - 1
    end
  end

  def add_navigation_params(params, current_page_path, current_page_number) do
    params
    |> Map.put("prev_page_path", current_page_path)
    |> Map.put("next_page", true)
    |> Map.put("prev_page_number", current_page_number)
  end
end
