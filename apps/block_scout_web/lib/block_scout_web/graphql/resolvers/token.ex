defmodule BlockScoutWeb.GraphQL.Resolvers.Token do
  @moduledoc false

  alias BlockScoutWeb.GraphQL.Resolvers.Helper
  alias Explorer.Chain.TokenTransfer
  alias Explorer.GraphQL

  def get_by(
        %TokenTransfer{token_contract_address_hash: token_contract_address_hash},
        _,
        resolution
      ) do
    if resolution.context.api_enabled do
      GraphQL.get_token(%{contract_address_hash: token_contract_address_hash})
    else
      {:error, Helper.api_is_disabled()}
    end
  end
end
