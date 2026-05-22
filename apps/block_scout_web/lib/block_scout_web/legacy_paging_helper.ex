defmodule BlockScoutWeb.LegacyPagingHelper do
  @moduledoc """
  Legacy pagination helpers for old UI controllers.
  New API v2 code should use BlockScoutWeb.Chain.paginate_list/3,4 instead.
  """

  import BlockScoutWeb.PagingHelper, only: [delete_parameters_from_next_page_params: 1]

  alias BlockScoutWeb.Chain

  @page_size 50

  def split_list_by_page(list_plus_one), do: Enum.split(list_plus_one, @page_size)

  @spec next_page_params(list(), list(), map(), (any() -> map())) :: nil | map()
  def next_page_params(next_page, list, params, paging_function \\ &Chain.paging_params/1)

  def next_page_params([], _list, _params, _), do: nil

  def next_page_params(_, list, params, paging_function) do
    paging_params = paging_function.(List.last(list))
    string_keys = map_to_string_keys(paging_params)

    params
    |> delete_parameters_from_next_page_params()
    |> Map.drop(string_keys)
    |> Map.merge(paging_params)
  end

  defp map_to_string_keys(map) do
    map
    |> Map.keys()
    |> Enum.map(fn
      key when is_atom(key) -> Atom.to_string(key)
      key -> key
    end)
  end
end
