defmodule BlockScoutWeb.Schemas.API.V2.General.AddressHash do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  OpenApiSpex.schema(%{type: :string, pattern: General.address_hash_pattern(), nullable: false})
end
