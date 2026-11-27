# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Transaction.Response do
  @moduledoc """
  This module defines the schema for transaction response from /api/v2/transactions/:transaction_hash_param.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Transaction
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(
    Transaction.schema()
    |> Helper.extend_schema(
      title: "TransactionResponse",
      description: "Transaction response"
    )
  )
end
