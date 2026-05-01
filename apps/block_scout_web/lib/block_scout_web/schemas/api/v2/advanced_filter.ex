defmodule BlockScoutWeb.Schemas.API.V2.AdvancedFilter do
  @moduledoc """
  Schema for a single item returned by the `/api/v2/advanced-filters` endpoint.

  Each item represents one unit of on-chain activity (a native value transfer,
  an internal transaction or a token transfer) projected through the advanced
  filters pipeline. See `Explorer.Chain.AdvancedFilter`.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General, Token, TokenTransfer}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AdvancedFilterItem",
    type: :object,
    properties: %{
      hash: General.FullHash,
      type: %Schema{
        type: :string,
        description:
          "Kind of activity represented by the item. Values include `coin_transfer`, `contract_interaction`, " <>
            "and `contract_creation` for top-level transactions and internal transactions, as well as " <>
            "token-transfer type labels (e.g. `ERC-20`, `ERC-721`, `ERC-1155`, `ERC-404`, `ERC-7984`) " <>
            "for token transfers.",
        nullable: false
      },
      status: %Schema{
        type: :string,
        description:
          "Execution status of the parent transaction. One of `pending`, `awaiting_internal_transactions`, " <>
            "`success`, or a free-form error reason string when the transaction reverted (e.g. `Reverted`).",
        nullable: false
      },
      method: General.MethodNameNullable,
      from: %Schema{
        allOf: [Address],
        nullable: true,
        description: "Sender address. `null` for contract-creation items."
      },
      to: %Schema{
        allOf: [Address],
        nullable: true,
        description: "Recipient address. `null` for contract-creation items and some internal transactions."
      },
      created_contract: %Schema{
        allOf: [Address],
        nullable: true,
        description: "Address of the contract deployed by this item. `null` unless the item is a contract creation."
      },
      value: %Schema{
        type: :string,
        pattern: General.integer_pattern(),
        nullable: true,
        description:
          "Native coin amount transferred, in the chain's base unit (e.g. wei). `null` for token-transfer items."
      },
      total: %Schema{
        anyOf: [
          TokenTransfer.TotalERC721,
          TokenTransfer.TotalERC1155,
          TokenTransfer.TotalERC7984,
          TokenTransfer.Total
        ],
        description:
          "Token transfer amount (or token id for NFTs). Populated only for token-transfer items; `null` otherwise.",
        nullable: true
      },
      token: %Schema{
        allOf: [Token],
        nullable: true,
        description: "Token contract metadata. Populated only for token-transfer items; `null` otherwise."
      },
      timestamp: %Schema{
        type: :string,
        format: :"date-time",
        nullable: false,
        description: "Block timestamp of the parent transaction."
      },
      block_number: %Schema{
        type: :integer,
        minimum: 0,
        nullable: false,
        description: "Number of the block that contains the parent transaction."
      },
      transaction_index: %Schema{
        type: :integer,
        minimum: 0,
        nullable: false,
        description: "Zero-based position of the parent transaction within its block."
      },
      internal_transaction_index: %Schema{
        type: :integer,
        minimum: 0,
        nullable: true,
        description:
          "Zero-based position of the internal transaction within its parent transaction. Populated only for " <>
            "internal-transaction items; `null` otherwise."
      },
      token_transfer_index: %Schema{
        type: :integer,
        minimum: 0,
        nullable: true,
        description:
          "Zero-based position of the token transfer, unique per parent transaction. Populated only for " <>
            "token-transfer items; `null` otherwise."
      },
      token_transfer_batch_index: %Schema{
        type: :integer,
        minimum: 0,
        nullable: true,
        description:
          "Zero-based position within an ERC-1155 batch token transfer. Populated only for items that belong " <>
            "to a batch; `null` otherwise."
      },
      fee: %Schema{
        type: :string,
        pattern: General.integer_pattern(),
        nullable: false,
        description: "Transaction fee paid by the sender, in the chain's base unit (e.g. wei)."
      }
    },
    required: [
      :hash,
      :type,
      :status,
      :method,
      :from,
      :to,
      :created_contract,
      :value,
      :total,
      :token,
      :timestamp,
      :block_number,
      :transaction_index,
      :internal_transaction_index,
      :token_transfer_index,
      :token_transfer_batch_index,
      :fee
    ],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.AdvancedFilter.SearchParams do
  @moduledoc """
  Auxiliary lookup map returned alongside advanced-filter items that echoes
  the resolved human-readable names of the `methods` and `tokens` used in the
  request filters.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Token
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AdvancedFilterSearchParams",
    type: :object,
    properties: %{
      methods: %Schema{
        type: :object,
        description:
          "Map of 4-byte method selectors (keys) to resolved method names (values) for the `methods` filter.",
        additionalProperties: %Schema{type: :string, nullable: false}
      },
      tokens: %Schema{
        type: :object,
        description:
          "Map of token contract address hashes (keys) to `Token` objects for tokens referenced in the " <>
            "`token_contract_address_hashes_to_include`/`_exclude` filters. At most 20 entries are returned " <>
            "(combined across both lists).",
        additionalProperties: Token
      }
    },
    required: [:methods, :tokens],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.AdvancedFilter.Response do
  @moduledoc """
  Schema for the paginated response returned by the `/api/v2/advanced-filters` endpoint.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.AdvancedFilter
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AdvancedFilterResponse",
    type: :object,
    properties: %{
      items: %Schema{type: :array, items: AdvancedFilter, nullable: false},
      search_params: AdvancedFilter.SearchParams,
      next_page_params: %Schema{
        type: :object,
        nullable: true,
        example: %{
          "block_number" => 23_532_302,
          "transaction_index" => 1,
          "internal_transaction_index" => nil,
          "token_transfer_index" => 0,
          "token_transfer_batch_index" => nil,
          "items_count" => 50
        }
      }
    },
    required: [:items, :search_params, :next_page_params],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.AdvancedFilter.CsvExportAccepted do
  @moduledoc """
  Schema for the 202 Accepted JSON body returned by
  `/api/v2/advanced-filters/csv` when asynchronous CSV export is enabled.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AdvancedFilterCsvExportAccepted",
    description:
      "Body returned when an asynchronous CSV export job has been queued. " <>
        "Poll `/api/v2/csv-exports/{request_id}` with the returned `request_id` to check status.",
    type: :object,
    properties: %{
      request_id: %Schema{
        type: :string,
        format: :uuid,
        description: "UUID of the queued export request.",
        nullable: false
      }
    },
    required: [:request_id],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.AdvancedFilter.CsvExportError do
  @moduledoc """
  Schema for the JSON error body returned by `/api/v2/advanced-filters/csv`
  when the asynchronous export job cannot be created (HTTP 409 or 500).

  Note: uses an `error` key rather than the `message` key carried by the
  reusable `ErrorResponses.*` schemas — the CSV controller predates that
  convention.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AdvancedFilterCsvExportError",
    type: :object,
    properties: %{
      error: %Schema{type: :string, nullable: false, description: "Human-readable error description."}
    },
    required: [:error],
    additionalProperties: false
  })
end
