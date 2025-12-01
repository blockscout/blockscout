defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.Count do
  @moduledoc """
  This module defines the schema for the Batch count value.
  """
  require OpenApiSpex

  OpenApiSpex.schema(%{type: :integer, nullable: true})
end
