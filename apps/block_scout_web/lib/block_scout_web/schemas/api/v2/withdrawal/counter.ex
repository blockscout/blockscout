defmodule BlockScoutWeb.Schemas.API.V2.Withdrawal.Counter do
  @moduledoc """
  This module defines the schema for the Withdrawal counters struct.
  """
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      withdrawals_count: General.IntegerString,
      withdrawals_sum: General.IntegerString
    },
    required: [
      :withdrawals_count,
      :withdrawals_sum
    ],
    additionalProperties: false
  })
end
