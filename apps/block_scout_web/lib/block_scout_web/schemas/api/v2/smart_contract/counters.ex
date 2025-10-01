defmodule BlockScoutWeb.Schemas.API.V2.SmartContract.Counters do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Smart contracts counters",
    type: :object,
    properties: %{
      smart_contracts: %Schema{type: :integer},
      new_smart_contracts_24h: %Schema{type: :integer},
      verified_smart_contracts: %Schema{type: :integer},
      new_verified_smart_contracts_24h: %Schema{type: :integer}
    }
  })
end
