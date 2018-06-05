defmodule Explorer.PagingOptions do
  @moduledoc """
  Defines paging options for paging by a stable key such as a timestamp or block
  number and index.
  """

  @type t :: %__MODULE__{key: key, page_size: page_size}

  @typep key :: any()
  @typep page_size :: non_neg_integer()

  defstruct [:key, :page_size]
end
