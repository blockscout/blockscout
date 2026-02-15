defmodule BlockScoutWeb.Schemas.API.V2.FheOperation do
  @moduledoc """
  This module defines the schema for the FHE Operation struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  @fhe_operation_type_enum [
    "arithmetic",
    "bitwise",
    "comparison",
    "unary",
    "control",
    "encryption",
    "random"
  ]

  @fhe_type_enum [
    "Bool",
    "Uint8",
    "Uint16",
    "Uint32",
    "Uint64",
    "Uint128",
    "Uint160",
    "Uint256",
    "Bytes64",
    "Bytes128",
    "Bytes256"
  ]

  @fhe_operation_inputs_schema %Schema{
    type: :object,
    properties: %{
      lhs: %Schema{type: :string, nullable: true},
      rhs: %Schema{type: :string, nullable: true},
      ct: %Schema{type: :string, nullable: true},
      control: %Schema{type: :string, nullable: true},
      if_true: %Schema{type: :string, nullable: true},
      if_false: %Schema{type: :string, nullable: true},
      plaintext: %Schema{type: :number, nullable: true}
    },
    additionalProperties: false
  }

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      log_index: %Schema{type: :integer, nullable: false},
      operation: %Schema{type: :string, nullable: false, example: "FheAdd"},
      type: %Schema{
        type: :string,
        enum: @fhe_operation_type_enum,
        nullable: false,
        example: "arithmetic"
      },
      fhe_type: %Schema{
        type: :string,
        enum: @fhe_type_enum,
        nullable: false,
        example: "Uint8"
      },
      is_scalar: %Schema{type: :boolean, nullable: false, example: false},
      hcu_cost: %Schema{type: :integer, nullable: false, example: 100, minimum: 0},
      hcu_depth: %Schema{type: :integer, nullable: false, example: 1, minimum: 0},
      caller: %Schema{allOf: [Address], nullable: true},
      inputs: @fhe_operation_inputs_schema,
      result: General.HexString,
      block_number: %Schema{type: :integer, nullable: false, example: 12_345_678}
    },
    required: [
      :log_index,
      :operation,
      :type,
      :fhe_type,
      :is_scalar,
      :hcu_cost,
      :hcu_depth,
      :inputs,
      :result,
      :block_number
    ],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.FheOperationsResponse do
  @moduledoc """
  This module defines the schema for the FHE Operations response from /api/v2/transactions/:transaction_hash_param/fhe-operations.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.FheOperation
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      items: %Schema{
        type: :array,
        items: %Schema{allOf: [FheOperation], nullable: false},
        nullable: false
      },
      total_hcu: %Schema{
        type: :integer,
        nullable: false,
        description: "Total HCU (Homomorphic Compute Units) cost for all operations in the transaction",
        example: 500,
        minimum: 0
      },
      max_depth_hcu: %Schema{
        type: :integer,
        nullable: false,
        description: "Maximum HCU depth across all operations in the transaction",
        example: 3,
        minimum: 0
      },
      operation_count: %Schema{
        type: :integer,
        nullable: false,
        description: "Total number of FHE operations in the transaction",
        example: 5,
        minimum: 0
      }
    },
    required: [:items, :total_hcu, :max_depth_hcu, :operation_count],
    additionalProperties: false
  })
end
