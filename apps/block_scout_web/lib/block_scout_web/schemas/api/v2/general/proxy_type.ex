defmodule BlockScoutWeb.Schemas.API.V2.General.ProxyType do
  @moduledoc false
  require OpenApiSpex
  alias Ecto.Enum
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation

  OpenApiSpex.schema(%{
    type: :string,
    enum: Enum.values(Implementation, :proxy_type),
    nullable: true
  })
end
