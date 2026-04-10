defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.BatchByAnytrust do
  @moduledoc """
  Arbitrum batch schema narrowed to AnyTrust data availability.

  Extends `Batch` by constraining `data_availability` to the AnyTrust variant only.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Arbitrum.Batch
  alias BlockScoutWeb.Schemas.API.V2.Arbitrum.DataAvailability
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(
    Batch.schema()
    |> Helper.extend_schema(
      title: "Arbitrum.BatchByAnytrust",
      description: "Arbitrum batch with AnyTrust data availability.",
      properties: %{
        data_availability: DataAvailability.Anytrust
      }
    )
  )
end
