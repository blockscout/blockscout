defmodule BlockScoutWeb.Schemas.API.V2.SmartContract.Counters do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    description: "Smart contracts counters",
    type: :object,
    properties: %{
      smart_contracts: General.IntegerString,
      new_smart_contracts_24h: General.IntegerString,
      verified_smart_contracts: General.IntegerString,
      new_verified_smart_contracts_24h: General.IntegerString
    }
  })
end
