defmodule BlockScoutWeb.Schema do
  @moduledoc false

  use Absinthe.Schema

  alias BlockScoutWeb.Resolvers.Block

  import_types(Absinthe.Type.Custom)
  import_types(BlockScoutWeb.Schema.Types)

  query do
    @desc "Gets a block by number."
    field :block, :block do
      arg(:number, non_null(:integer))
      resolve(&Block.get_by/3)
    end
  end
end
