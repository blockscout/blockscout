defmodule Explorer.Logger do
  @moduledoc """
  Extensions to `Logger`.
  """

  @doc """
  Sets `keyword` in `Logger.metadata/1` around `fun`.
  """
  def metadata(keyword, fun) when is_list(keyword) and is_function(fun, 0) do
    metadata_before = Logger.metadata()

    try do
      Logger.metadata(keyword)
      fun.()
    after
      Logger.reset_metadata(metadata_before)
    end
  end
end
