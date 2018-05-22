defmodule ExplorerWeb.BlockPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 2]

  alias Explorer.Chain.Block

  def detail_number(%Block{number: block_number}) do
    css("[data-test='block_detail_number']", text: to_string(block_number))
  end
end
