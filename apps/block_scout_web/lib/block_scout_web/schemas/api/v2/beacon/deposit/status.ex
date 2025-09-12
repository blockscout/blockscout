defmodule BlockScoutWeb.Schemas.API.V2.Beacon.Deposit.Status do
  @moduledoc false
  require OpenApiSpex

  alias Explorer.Chain.Beacon.Deposit

  OpenApiSpex.schema(%{type: :string, nullable: false, enum: Deposit.statuses()})
end
