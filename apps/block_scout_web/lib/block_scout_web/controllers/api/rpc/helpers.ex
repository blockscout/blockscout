defmodule BlockScoutWeb.API.RPC.Helpers do
  @moduledoc """
  Small helpers for RPC api controllers.
  """
  alias Explorer.Etherscan

  def put_pagination_options(options, params) do
    options
    |> put_page_option(params)
    |> put_offset_option(params)
  end

  def put_page_option(options, %{"page" => page}) do
    case Integer.parse(page) do
      {page_number, ""} when page_number > 0 ->
        Map.put(options, :page_number, page_number)

      _ ->
        options
    end
  end

  def put_page_option(options, _), do: options

  def put_offset_option(options, %{"offset" => offset}) do
    with {page_size, ""} when page_size > 0 <- Integer.parse(offset),
         :ok <- validate_max_page_size(page_size) do
      Map.put(options, :page_size, page_size)
    else
      _ ->
        options
    end
  end

  def put_offset_option(options, _) do
    options
  end

  defp validate_max_page_size(page_size) do
    if page_size <= Etherscan.page_size_max(), do: :ok, else: :error
  end
end
