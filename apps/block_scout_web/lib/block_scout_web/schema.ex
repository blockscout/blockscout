defmodule BlockScoutWeb.Schema do
  @moduledoc false

  use Absinthe.Schema

  alias BlockScoutWeb.Resolvers.{Block, Transaction}

  import_types(BlockScoutWeb.Schema.Types)

  query do
    @desc "Gets a block by number."
    field :block, :block do
      arg(:number, non_null(:integer))
      resolve(&Block.get_by/3)
    end

    @desc "Gets a transaction by hash."
    field :transaction, :transaction do
      arg(:hash, non_null(:full_hash))
      resolve(&Transaction.get_by/3)
    end
  end
end
