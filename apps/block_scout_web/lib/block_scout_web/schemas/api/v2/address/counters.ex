defmodule BlockScoutWeb.Schemas.API.V2.Address.Counters do
  @moduledoc """
  This module defines the schema for address counters.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    title: "AddressCounters",
    description: "Address counters",
    type: :object,
    properties: %{
      transactions_count: General.IntegerString,
      token_transfers_count: General.IntegerString,
      gas_usage_count: General.IntegerString,
      validations_count: General.IntegerString
    },
    required: [:transactions_count, :token_transfers_count, :gas_usage_count, :validations_count]
  })
end
