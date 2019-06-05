defmodule Explorer.PagingOptions do
  @moduledoc """
  Defines paging options for paging by a stable key such as a timestamp or block
  number and index.
  """

  @type t :: %__MODULE__{key: key, page_size: page_size, page_number: page_number}

  @typep key :: any()
  @typep page_size :: non_neg_integer()
  @typep page_number :: pos_integer()

  defstruct [:key, :page_size, page_number: 1]
end
