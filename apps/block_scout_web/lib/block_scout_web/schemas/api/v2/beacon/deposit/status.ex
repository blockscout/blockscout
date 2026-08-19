# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Beacon.Deposit.Status do
  @moduledoc false
  require OpenApiSpex

  alias Explorer.Chain.Beacon.Deposit

  OpenApiSpex.schema(%{
    title: "Beacon.Deposit.Status",
    type: :string,
    nullable: false,
    enum: Deposit.statuses() |> Enum.map(&to_string/1),
    description: "Beacon deposit lifecycle status."
  })
end
