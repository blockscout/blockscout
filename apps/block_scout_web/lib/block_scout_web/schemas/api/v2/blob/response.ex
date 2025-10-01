defmodule BlockScoutWeb.Schemas.API.V2.Blob.Response do
  @moduledoc """
  This module defines the schema for blob response from /api/v2/transactions/:transaction_hash_param/blobs.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Blob
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(
    Blob.schema()
    |> Helper.extend_schema(
      title: "BlobResponse",
      description: "Blob response",
      additionalProperties: false
    )
  )
end
