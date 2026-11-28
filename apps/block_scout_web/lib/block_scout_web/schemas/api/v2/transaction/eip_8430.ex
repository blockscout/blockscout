# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Transaction.EIP8430 do
  @moduledoc """
  This module defines the schema for the fields that only an EIP-8430 transaction
  (EIP-2718 type `0x79`) has.

  A transaction list returns only `resolved_payer`. The transaction endpoint
  returns all fields.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "TransactionEIP8430",
    description:
      "Fields of an EIP-8430 transaction (type 0x79). A transaction list returns only `resolved_payer`. The transaction endpoint returns all fields.",
    type: :object,
    properties: %{
      resolved_payer: %Schema{
        allOf: [Address],
        nullable: true,
        description: "Account that pays the transaction fee. `null` for a pending transaction."
      },
      # Enum values must be kept in sync with Explorer.Chain.EIP8430Transaction :payer_type field.
      payer_type: %Schema{
        type: :string,
        enum: ["self", "open", "named", "unknown"],
        nullable: false,
        description:
          "How the transaction selects the payer. `self`: the sender pays. `open`: the transaction does not name the payer, and each account can pay. `named`: the transaction names the payer. `unknown`: the payer value has an unexpected form."
      },
      nonce_key: %Schema{
        allOf: [General.NonNegativeIntegerString],
        description:
          "Nonce channel: a separate sequence of nonces for one sender. `0` means that `nonce` is the account nonce."
      },
      valid_after: %Schema{
        allOf: [General.NonNegativeIntegerString],
        description: "Lower time bound of the transaction, as the node returns it. `0` means no bound."
      },
      valid_before: %Schema{
        allOf: [General.NonNegativeIntegerString],
        description: "Upper time bound of the transaction, as the node returns it. `0` means no bound."
      },
      committed_phases_count: %Schema{
        type: :integer,
        minimum: 0,
        nullable: true,
        description:
          "Number of call phases that committed. The phases operate in sequence and stop at the first revert. `null` for a pending transaction."
      },
      metadata: %Schema{
        allOf: [General.HexDataNullable],
        description: "Opaque bytes that the sender attaches to the transaction."
      },
      account_changes: %Schema{
        nullable: true,
        description: "Account changes of the transaction, in the form that the node returns."
      },
      has_named_sender: %Schema{
        type: :boolean,
        nullable: false,
        description:
          "`true` if the transaction names its sender. `false` if the node recovers the sender from the sender authorization."
      }
    },
    required: [:resolved_payer],
    additionalProperties: false
  })
end
