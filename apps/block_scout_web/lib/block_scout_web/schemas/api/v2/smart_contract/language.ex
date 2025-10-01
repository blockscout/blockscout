defmodule BlockScoutWeb.Schemas.API.V2.SmartContract.Language do
  @moduledoc false
  require OpenApiSpex

  alias Explorer.Chain.SmartContract

  OpenApiSpex.schema(%{type: :string, enum: SmartContract.language_strings()})
end
