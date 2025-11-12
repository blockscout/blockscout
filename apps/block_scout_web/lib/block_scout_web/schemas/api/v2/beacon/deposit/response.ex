defmodule BlockScoutWeb.Schemas.API.V2.Beacon.Deposit.Response do
  @moduledoc """
  This module defines the schema for beacon deposit response from /api/v2/transactions/:transaction_hash_param/beacon/deposits.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Beacon.Deposit
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(
    Deposit.schema()
    |> Helper.extend_schema(
      title: "BeaconDepositResponse",
      description: "BeaconDeposit response",
      additionalProperties: false
    )
  )
end
