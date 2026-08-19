# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.InBlob4844 do
  @moduledoc """
  Detailed Optimism batch whose data is stored in EIP-4844 blobs.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch
  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch.Blob
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Batch.schema()
    |> Helper.extend_schema(
      title: "OptimismBatchInBlob4844",
      properties: %{
        batch_data_container: %Schema{type: :string, enum: ["in_blob4844"], nullable: false},
        blobs: %Schema{type: :array, items: Blob.Eip4844, nullable: false}
      },
      required: [:blobs]
    )
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.InCelestia do
  @moduledoc """
  Detailed Optimism batch whose data is stored on Celestia.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch
  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch.Blob
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Batch.schema()
    |> Helper.extend_schema(
      title: "OptimismBatchInCelestia",
      properties: %{
        batch_data_container: %Schema{type: :string, enum: ["in_celestia"], nullable: false},
        blobs: %Schema{type: :array, items: Blob.Celestia, nullable: false}
      },
      required: [:blobs]
    )
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.InEigenda do
  @moduledoc """
  Detailed Optimism batch whose data is stored on EigenDA.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch
  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch.Blob
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Batch.schema()
    |> Helper.extend_schema(
      title: "OptimismBatchInEigenda",
      properties: %{
        batch_data_container: %Schema{type: :string, enum: ["in_eigenda"], nullable: false},
        blobs: %Schema{type: :array, items: Blob.Eigenda, nullable: false}
      },
      required: [:blobs]
    )
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.InAltDa do
  @moduledoc """
  Detailed Optimism batch whose data is stored via an Alt-DA provider.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch
  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch.Blob
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Batch.schema()
    |> Helper.extend_schema(
      title: "OptimismBatchInAltDa",
      properties: %{
        batch_data_container: %Schema{type: :string, enum: ["in_alt_da"], nullable: false},
        blobs: %Schema{type: :array, items: Blob.AltDa, nullable: false}
      },
      required: [:blobs]
    )
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.InCalldata do
  @moduledoc """
  Detailed Optimism batch whose data is stored in L1 calldata. No `blobs` are
  present in this case.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Batch.schema()
    |> Helper.extend_schema(
      title: "OptimismBatchInCalldata",
      properties: %{
        batch_data_container: %Schema{type: :string, enum: ["in_calldata"], nullable: false}
      }
    )
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.Detailed do
  @moduledoc """
  Detailed batch response from `/api/v2/optimism/batches/:number` and
  `/api/v2/optimism/batches/da/celestia/:height/:commitment`.

  Modeled as a discriminated union on `batch_data_container`: each variant pins
  the container value and carries the matching `blobs` item shape (the `in_calldata`
  variant carries no `blobs`). Mirrors
  `Explorer.Chain.Optimism.FrameSequenceBlob.filter_blobs_by_type/1`.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch

  OpenApiSpex.schema(%{
    title: "OptimismBatchDetailed",
    type: :object,
    oneOf: [
      Batch.InBlob4844,
      Batch.InCelestia,
      Batch.InEigenda,
      Batch.InAltDa,
      Batch.InCalldata
    ],
    discriminator: %OpenApiSpex.Discriminator{
      propertyName: "batch_data_container",
      mapping: %{
        "in_blob4844" => "#/components/schemas/OptimismBatchInBlob4844",
        "in_celestia" => "#/components/schemas/OptimismBatchInCelestia",
        "in_eigenda" => "#/components/schemas/OptimismBatchInEigenda",
        "in_alt_da" => "#/components/schemas/OptimismBatchInAltDa",
        "in_calldata" => "#/components/schemas/OptimismBatchInCalldata"
      }
    }
  })
end
