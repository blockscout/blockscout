defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.BatchByCelestia do
  @moduledoc """
  Arbitrum batch schema narrowed to Celestia data availability.

  Extends `Batch` by constraining `data_availability` to the Celestia variant only.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Arbitrum.Batch
  alias BlockScoutWeb.Schemas.API.V2.Arbitrum.DataAvailability
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(
    Batch.schema()
    |> Helper.extend_schema(
      title: "Arbitrum.BatchByCelestia",
      description: "Arbitrum batch with Celestia data availability.",
      properties: %{
        data_availability: DataAvailability.Celestia
      }
    )
  )
end
