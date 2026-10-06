# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.Blob.Eip4844 do
  @moduledoc """
  Blob item bound to an Optimism batch whose data is stored in EIP-4844 blobs
  (`batch_data_container == "in_blob4844"`).
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "OptimismBlobEip4844",
    type: :object,
    properties: %{
      hash: %Schema{
        type: :string,
        pattern: General.hex_data_pattern(),
        nullable: false,
        description: "EIP-4844 blob hash."
      },
      l1_transaction_hash: General.FullHash,
      l1_timestamp: General.Timestamp
    },
    required: [:hash, :l1_transaction_hash, :l1_timestamp],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.Blob.Celestia do
  @moduledoc """
  Blob item bound to an Optimism batch whose data is stored on Celestia
  (`batch_data_container == "in_celestia"`).
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "OptimismBlobCelestia",
    type: :object,
    properties: %{
      height: %Schema{type: :integer, nullable: false, description: "Celestia block height."},
      namespace: %Schema{
        type: :string,
        pattern: General.hex_data_pattern(),
        nullable: false,
        description: "Celestia blob namespace."
      },
      commitment: %Schema{
        type: :string,
        pattern: General.hex_data_pattern(),
        nullable: false,
        description: "Celestia blob commitment."
      },
      l1_transaction_hash: General.FullHash,
      l1_timestamp: General.Timestamp
    },
    required: [:height, :namespace, :commitment, :l1_transaction_hash, :l1_timestamp],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.Blob.Eigenda do
  @moduledoc """
  Blob item bound to an Optimism batch whose data is stored on EigenDA
  (`batch_data_container == "in_eigenda"`).
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "OptimismBlobEigenda",
    type: :object,
    properties: %{
      cert: %Schema{
        type: :string,
        pattern: General.hex_data_pattern(),
        nullable: false,
        description: "EigenDA cert raw bytes."
      },
      l1_transaction_hash: General.FullHash,
      l1_timestamp: General.Timestamp
    },
    required: [:cert, :l1_transaction_hash, :l1_timestamp],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.Blob.AltDa do
  @moduledoc """
  Blob item bound to an Optimism batch whose data is stored via an Alt-DA provider
  (`batch_data_container == "in_alt_da"`).
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "OptimismBlobAltDa",
    type: :object,
    properties: %{
      commitment: %Schema{
        type: :string,
        pattern: General.hex_data_pattern(),
        nullable: false,
        description: "Alt-DA blob commitment."
      },
      l1_transaction_hash: General.FullHash,
      l1_timestamp: General.Timestamp
    },
    required: [:commitment, :l1_transaction_hash, :l1_timestamp],
    additionalProperties: false
  })
end
