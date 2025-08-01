defmodule BlockScoutWeb.GraphQL.Resolvers.Token do
  @moduledoc false

  alias Explorer.Chain.TokenTransfer
  alias Explorer.GraphQL

  def get_by(%TokenTransfer{token_contract_address_hash: token_contract_address_hash}, _, _) do
    GraphQL.get_token(%{contract_address_hash: token_contract_address_hash})
  end
end
