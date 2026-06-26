# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.General.FilecoinActorType do
  @moduledoc """
  Reusable enum of Filecoin actor types.

  Mirrors the `:filecoin_actor_type` Ecto enum on `Explorer.Chain.Address`
  (which only exists for the `:filecoin` chain type, hence the compile-time guard).
  """
  require OpenApiSpex

  alias Ecto.Enum, as: EctoEnum
  alias Explorer.Chain.Address

  # Resolved at compile time. On filecoin builds this stays in sync with the Ecto
  # enum; on other chain types the field does not exist and this schema is unused.
  @actor_type_values (case Application.compile_env(:explorer, :chain_type) do
                        :filecoin -> EctoEnum.values(Address, :filecoin_actor_type)
                        _ -> []
                      end)

  OpenApiSpex.schema(%{
    title: "FilecoinActorType",
    type: :string,
    enum: @actor_type_values,
    nullable: false,
    description: "Type of actor associated with a Filecoin address."
  })
end
