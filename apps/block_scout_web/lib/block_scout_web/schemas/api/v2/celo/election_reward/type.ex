defmodule BlockScoutWeb.Schemas.API.V2.Celo.ElectionReward.Type do
  @moduledoc false
  require OpenApiSpex

  alias Explorer.Chain.Celo.ElectionReward

  OpenApiSpex.schema(%{type: :string, nullable: false, enum: ElectionReward.types()})
end
