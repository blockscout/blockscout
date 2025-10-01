defmodule BlockScoutWeb.Schemas.API.V2.Blob do
  @moduledoc "OpenAPI schema for Blob responses."

  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      blob_data: General.HexString,
      hash: General.FullHash,
      kzg_commitment: General.HexString,
      kzg_proof: General.HexString
    },
    required: [:blob_data, :hash, :kzg_commitment, :kzg_proof],
    additionalProperties: false
  })
end
