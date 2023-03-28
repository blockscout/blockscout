defmodule Explorer.Logger do
  @moduledoc """
  Helper for `Logger`.
  """

  @doc """
  Sets `keyword` in `Logger.metadata/1` around `fun`.
  """
  def metadata(fun, keyword) when is_function(fun, 0) and is_list(keyword) do
    metadata_before = Logger.metadata()

    try do
      Logger.metadata(keyword)
      fun.()
    after
      Logger.reset_metadata(metadata_before)
    end
  end
end
