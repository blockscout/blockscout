defmodule BlockScoutWeb.Schemas.API.V2.General do
  @moduledoc """
  This module defines the schema for general types used in the API.
  """
  require OpenApiSpex
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias BlockScoutWeb.Schemas.API.V2.Celo.ElectionReward.Type, as: CeloElectionRewardType

  alias BlockScoutWeb.Schemas.API.V2.General.{
    AddressHash,
    AddressHashNullable,
    EmptyString,
    FloatString,
    FullHash,
    HexString,
    IntegerString,
    IntegerStringNullable,
    NullString
  }

  alias BlockScoutWeb.Schemas.API.V2.Token.Type, as: TokenType
  alias Explorer.Chain.InternalTransaction.CallType
  alias OpenApiSpex.{Parameter, Schema}
  @integer_pattern ~r"^-?([1-9][0-9]*|0)$"
  @float_pattern ~r"^([1-9][0-9]*|0)(\.[0-9]+)?$"
  @address_hash_pattern ~r"^0x([A-Fa-f0-9]{40})$"
  @full_hash_pattern ~r"^0x([A-Fa-f0-9]{64})$"
  @hex_string_pattern ~r"^0x([A-Fa-f0-9]*)$"

  if @chain_type == :zilliqa do
    @token_type_pattern ~r/^\[?(ERC-20|ERC-721|ERC-1155|ERC-404|ZRC-2|ERC-7984)(,(ERC-20|ERC-721|ERC-1155|ERC-404|ZRC-2|ERC-7984))*\]?$/i
  else
    @token_type_pattern ~r/^\[?(ERC-20|ERC-721|ERC-1155|ERC-404|ERC-7984)(,(ERC-20|ERC-721|ERC-1155|ERC-404|ERC-7984))*\]?$/i
  end

  # Matches ISO-like datetime strings where separators between time fields can be ':' or percent-encoded '%3A'.
  # Accepts examples like:
  #  - "2025-10-12T09"
  #  - "2025-10-12T09:51"
  #  - "2025-10-12T09:51:00.000Z"
  #  - "2025-10-12T09%3A51%3A00.000Z"
  #  - With timezone offsets: "2025-10-12T09:51:00+02:00" or encoded as "%2B02%3A00"
  @iso_date_or_datetime_pattern ~r"^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])(?:T(?:[01]\d|2[0-3])(?:(?::|%3A)[0-5]\d(?:(?::|%3A)[0-5]\d(?:\.\d{1,9})?)?)?(?:Z|(?:\+|%2B|-)(?:[01]\d|2[0-3])(?:(?::|%3A)[0-5]\d)?)?)?$"i

  @base_transaction_types [
    "coin_transfer",
    "contract_call",
    "contract_creation",
    "token_transfer",
    "token_creation"
  ]

  case @chain_type do
    :ethereum ->
      @allowed_transaction_types ["blob_transaction" | @base_transaction_types]

    _ ->
      @allowed_transaction_types @base_transaction_types
  end

  @doc """
  Returns a parameter definition for an address hash in the path.
  """
  @spec address_hash_param() :: Parameter.t()
  def address_hash_param do
    %Parameter{
      name: :address_hash_param,
      in: :path,
      schema: AddressHash,
      required: true,
      description: "Address hash in the path"
    }
  end

  @doc """
  Returns a parameter definition for the start of the time period.
  """
  @spec from_period_param() :: Parameter.t()
  def from_period_param do
    %Parameter{
      name: :from_period,
      in: :query,
      schema: %Schema{
        anyOf: [%Schema{type: :string, nullable: false, pattern: @iso_date_or_datetime_pattern}, NullString]
      },
      required: true,
      description: "Start of the time period (ISO 8601 format) in CSV export"
    }
  end

  @doc """
  Returns a parameter definition for the end of the time period.
  """
  @spec to_period_param() :: Parameter.t()
  def to_period_param do
    %Parameter{
      name: :to_period,
      in: :query,
      schema: %Schema{
        anyOf: [%Schema{type: :string, nullable: false, pattern: @iso_date_or_datetime_pattern}, NullString]
      },
      required: true,
      description: "End of the time period (ISO 8601 format) In CSV export"
    }
  end

  @doc """
  Returns a parameter definition for chain IDs in the query.
  """
  @spec chain_ids_param() :: Parameter.t()
  def chain_ids_param do
    %Parameter{
      name: :chain_ids,
      in: :query,
      schema: %Schema{type: :string, nullable: true},
      required: false,
      description: "Chain IDs filter in Bridged tokens"
    }
  end

  @doc """
  Returns a parameter definition for a search query in the query.
  """
  @spec q_param() :: Parameter.t()
  def q_param do
    %Parameter{
      name: :q,
      in: :query,
      schema: %Schema{type: :string, nullable: true},
      required: false,
      description: "Search query filter"
    }
  end

  @doc """
  Returns a parameter definition for a limit result items in the response.
  """
  @spec limit_param() :: Parameter.t()
  def limit_param do
    %Parameter{
      name: :limit,
      in: :query,
      schema: %Schema{type: :integer, nullable: true},
      required: false,
      description: "Limit result items in the response"
    }
  end

  @doc """
  Returns a parameter definition for a filter type in the query.
  """
  @spec filter_type_param() :: Parameter.t()
  def filter_type_param do
    %Parameter{
      name: :filter_type,
      in: :query,
      schema: %Schema{anyOf: [%Schema{type: :string, enum: ["address"], nullable: true}, NullString]},
      required: false,
      description: "Filter type in CSV export"
    }
  end

  @doc """
  Returns a parameter definition for a filter value in the query.
  """
  @spec filter_value_param() :: Parameter.t()
  def filter_value_param do
    %Parameter{
      name: :filter_value,
      in: :query,
      schema: %Schema{anyOf: [%Schema{type: :string, enum: ["to", "from"], nullable: true}, NullString]},
      required: false,
      description: "Filter value in CSV export"
    }
  end

  @doc """
  Returns a parameter definition for a token holder address hash in the query.
  """
  @spec holder_address_hash_param() :: Parameter.t()
  def holder_address_hash_param do
    %Parameter{
      name: :holder_address_hash,
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Token holder address hash in the query"
    }
  end

  @doc """
  Returns a parameter definition for an execution_node hash in the path.
  """
  @spec execution_node_hash_param() :: Parameter.t()
  def execution_node_hash_param do
    %Parameter{
      name: :execution_node_hash_param,
      in: :path,
      schema: AddressHash,
      required: true,
      description: "Execution node hash in the path"
    }
  end

  @doc """
  Returns a parameter definition for a transaction hash in the path.
  """
  @spec transaction_hash_param() :: Parameter.t()
  def transaction_hash_param do
    %Parameter{
      name: :transaction_hash_param,
      in: :path,
      schema: FullHash,
      required: true,
      description: "Transaction hash in the path"
    }
  end

  @doc """
  Returns a parameter definition for a transaction hash in the query.
  """
  @spec query_transaction_hash_param() :: Parameter.t()
  def query_transaction_hash_param do
    %Parameter{
      name: :transaction_hash,
      in: :query,
      schema: FullHash,
      required: false,
      description: "Transaction hash in the query"
    }
  end

  @doc """
  Returns a parameter definition for a block hash or number in the path.
  """
  @spec block_hash_or_number_param() :: Parameter.t()
  def block_hash_or_number_param do
    %Parameter{
      name: :block_hash_or_number_param,
      in: :path,
      schema: %Schema{anyOf: [%Schema{type: :integer, minimum: 0}, FullHash]},
      required: true,
      description: "Block hash or number in the path"
    }
  end

  @doc """
  Returns a parameter definition for a block number in the path.
  """
  @spec block_number_param() :: Parameter.t()
  def block_number_param do
    %Parameter{
      name: :block_number_param,
      in: :path,
      schema: %Schema{type: :integer, minimum: 0},
      required: true,
      description: "Block number in the path"
    }
  end

  @doc """
  Returns a parameter definition for filtering blocks by type (uncle or reorg).
  """
  @spec block_type_param() :: Parameter.t()
  def block_type_param do
    %Parameter{
      name: :type,
      in: :query,
      schema: %Schema{type: :string, enum: ["uncle", "reorg", "block"]},
      required: false,
      description: """
      Filter by block type:
      * block - Standard blocks in the main chain
      * uncle - Uncle/ommer blocks (valid but not in main chain)
      * reorg - Blocks from chain reorganizations
      If omitted, default value "block" is used.
      """
    }
  end

  @doc """
  Returns a parameter definition for filtering transactions by type (validated or pending).
  """
  @spec transaction_filter_param() :: Parameter.t()
  def transaction_filter_param do
    %Parameter{
      name: :filter,
      in: :query,
      schema: %Schema{type: :string, enum: ["validated", "pending"]},
      required: false,
      description: """
      Filter transactions by status:
      * pending - Transactions waiting to be mined/validated
      * validated - Confirmed transactions included in blocks
      If omitted, default value "validated" is used.
      """
    }
  end

  @doc """
  Returns a parameter definition for a request body used in the summary endpoint.
  """
  @spec just_request_body_param() :: Parameter.t()
  def just_request_body_param do
    %Parameter{
      name: :just_request_body,
      in: :query,
      schema: %Schema{type: :boolean},
      required: false,
      description: "If true, returns only the request body in the summary endpoint"
    }
  end

  @doc """
  Returns a reusable OpenApiSpex.RequestBody for audit report submission.
  """
  @spec audit_report_request_body() :: OpenApiSpex.RequestBody.t()
  def audit_report_request_body do
    %OpenApiSpex.RequestBody{
      content: %{
        "application/json" => %OpenApiSpex.MediaType{
          schema: %OpenApiSpex.Schema{
            type: :object,
            properties: %{
              submitter_name: %Schema{type: :string},
              submitter_email: %Schema{type: :string},
              is_project_owner: %Schema{type: :boolean},
              project_name: %Schema{type: :string},
              project_url: %Schema{type: :string},
              audit_company_name: %Schema{type: :string},
              audit_report_url: %Schema{type: :string},
              audit_publish_date: %Schema{type: :string, format: :date},
              comment: %Schema{type: :string, nullable: true}
            },
            required: [
              :submitter_name,
              :submitter_email,
              :is_project_owner,
              :project_name,
              :project_url,
              :audit_company_name,
              :audit_report_url,
              :audit_publish_date
            ]
          }
        }
      }
    }
  end

  @doc """
  Returns a parameter definition for a batch number in the path.
  """
  @spec batch_number_param() :: Parameter.t()
  def batch_number_param do
    %Parameter{
      name: :batch_number_param,
      in: :path,
      schema: %Schema{type: :integer, minimum: 0},
      required: true,
      description: "Batch number"
    }
  end

  @doc """
  Returns a parameter definition for filtering transactions by type.
  """
  @spec transaction_type_param() :: Parameter.t()
  def transaction_type_param do
    %Parameter{
      name: :type,
      in: :query,
      schema: %Schema{type: :string, enum: ["blob_transaction"]},
      required: false,
      description: """
      Filter by transaction type. Comma-separated list of:
      * blob_transaction - Only show blob transactions
      """
    }
  end

  @doc """
  Returns a parameter definition for filtering block transactions by type.
  """
  @spec block_transaction_type_param() :: Parameter.t()
  def block_transaction_type_param do
    %Parameter{
      name: :type,
      in: :query,
      schema: %Schema{type: :string, enum: @allowed_transaction_types},
      required: false,
      description: """
      Filter by transaction type. Comma-separated list of:
      * token_transfer - Token transfer transactions
      * contract_creation - Contract deployment transactions
      * contract_call - Contract method call transactions
      * coin_transfer - Native coin transfer transactions
      * token_creation - Token creation transactions
      * blob_transaction - Only show blob transactions (Ethereum only)
      """
    }
  end

  @doc """
  Returns a parameter definition for filtering internal transactions by type.
  """
  @spec internal_transaction_type_param() :: Parameter.t()
  def internal_transaction_type_param do
    %Parameter{
      name: :internal_type,
      in: :query,
      schema: %Schema{
        type: :string,
        enum: Explorer.Chain.InternalTransaction.Type.values()
      },
      required: false,
      description: """
      Filter internal transactions by type:
      * all - Show all internal transactions (default)
      * call - Only show call internal transactions
      * create - Only show create internal transactions
      * create2 - Only show create2 internal transactions
      * reward - Only show reward internal transactions
      * selfdestruct - Only show selfdestruct internal transactions
      * stop - Only show stop internal transactions
      * invalid - Only show invalid internal transactions (Arbitrum only)
      """
    }
  end

  @doc """
  Returns a parameter definition for filtering internal transactions by call type.
  """
  @spec internal_transaction_call_type_param() :: Parameter.t()
  def internal_transaction_call_type_param do
    %Parameter{
      name: :call_type,
      in: :query,
      schema: %Schema{
        type: :string,
        enum: CallType.values()
      },
      required: false,
      description: """
      Filter internal transactions by call type:
      * all - Show all internal transactions (default)
      * call - Only show call internal transactions
      * callcode - Only show callcode internal transactions
      * delegatecall - Only show delegatecall internal transactions
      * staticcall - Only show staticcall internal transactions
      * invalid - Only show invalid internal transactions (Arbitrum only)
      """
    }
  end

  @doc """
  Returns a parameter definition for filtering transactions by direction (to/from).
  """
  @spec direction_filter_param() :: Parameter.t()
  def direction_filter_param do
    %Parameter{
      name: :filter,
      in: :query,
      schema: %Schema{type: :string, enum: ["to", "from"]},
      required: false,
      description: """
      Filter transactions by direction:
      * to - Only show transactions sent to this address
      * from - Only show transactions sent from this address
      If omitted, all transactions involving the address are returned.
      """
    }
  end

  @doc """
  Returns a parameter definition for sorting transactions by specified fields.
  """
  @spec sort_param([String.t()]) :: Parameter.t()
  def sort_param(sort_fields) do
    %Parameter{
      name: :sort,
      in: :query,
      schema: %Schema{
        type: :string,
        enum: sort_fields
      },
      required: false,
      description: """
      Sort transactions by:
      * block_number - Sort by block number
      * value - Sort by transaction value
      * fee - Sort by transaction fee
      * balance - Sort by account balance
      * transactions_count - Sort by number of transactions on address
      * fiat_value - Sort by fiat value of the token transfer
      * holders_count - Sort by number of token holders
      * circulating_market_cap - Sort by circulating market cap of the token
      Should be used together with `order` parameter.
      """
    }
  end

  @doc """
  Returns a parameter definition for sorting order (asc/desc).
  """
  @spec order_param() :: Parameter.t()
  def order_param do
    %Parameter{
      in: :query,
      schema: %Schema{
        type: :string,
        enum: ["asc", "desc"]
      },
      required: false,
      description: """
      Sort order:
      * asc - Ascending order
      * desc - Descending order
      Should be used together with `sort` parameter.
      """,
      name: :order
    }
  end

  @token_type_param_description """
  Filter by token type. Comma-separated list of:
  * ERC-20 - Fungible tokens
  * ERC-721 - Non-fungible tokens
  * ERC-1155 - Multi-token standard
  * ERC-404 - Hybrid fungible/non-fungible tokens
  #{if @chain_type == :zilliqa do
    """
    * ZRC-2 - Fungible tokens on Zilliqa
    """
  else
    ""
  end}

  Example: `ERC-20,ERC-721` to show both fungible and NFT transfers
  """

  @doc """
  Returns a parameter definition for filtering by token type.
  """
  @spec token_type_param() :: Parameter.t()
  def token_type_param do
    %Parameter{
      name: :type,
      in: :query,
      schema: %Schema{
        anyOf: [
          EmptyString,
          %Schema{
            type: :string,
            pattern: @token_type_pattern
          }
        ]
      },
      required: false,
      description: @token_type_param_description
    }
  end

  @doc """
  Returns a parameter definition for filtering by NFT token type.
  """
  @spec nft_token_type_param() :: Parameter.t()
  def nft_token_type_param do
    %Parameter{
      name: :type,
      in: :query,
      schema: %Schema{
        anyOf: [
          EmptyString,
          %Schema{
            type: :string,
            pattern: @token_type_pattern
          }
        ]
      },
      required: false,
      description: """
      Filter by token type. Comma-separated list of:
      * ERC-721 - Non-fungible tokens
      * ERC-1155 - Multi-token standard
      * ERC-404 - Hybrid fungible/non-fungible tokens

      Example: `ERC-721,ERC-1155` to show both NFT and multi-token transfers
      """
    }
  end

  @doc """
  Returns a parameter definition for filtering logs by topic.
  """
  @spec topic_param() :: Parameter.t()
  def topic_param do
    %Parameter{
      name: :topic,
      in: :query,
      schema: HexString,
      required: false,
      description: "Log topic param in the query"
    }
  end

  @doc """
  Returns a parameter definition for filtering token transfers by token contract address.
  """
  @spec token_filter_param() :: Parameter.t()
  def token_filter_param do
    %Parameter{
      name: :token,
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Filter token transfers by token contract address."
    }
  end

  @doc """
  Returns a parameter definition for a token ID in the path.
  """
  @spec token_id_param() :: Parameter.t()
  def token_id_param do
    %Parameter{
      name: :token_id_param,
      in: :path,
      schema: IntegerStringNullable,
      required: true,
      description: "Token ID for ERC-721/1155/404 tokens"
    }
  end

  @doc """
  Returns a parameter definition for API key for sensitive endpoints in the query string.
  """
  @spec admin_api_key_param_query() :: Parameter.t()
  def admin_api_key_param_query do
    %Parameter{
      name: :api_key,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "API key required for sensitive endpoints"
    }
  end

  @doc """
  Returns a parameter definition for API key header for sensitive endpoints.
  """
  @spec admin_api_key_param() :: Parameter.t()
  def admin_api_key_param do
    %Parameter{
      name: :"x-api-key",
      in: :header,
      schema: %Schema{type: :string},
      required: false,
      description: "API key required for sensitive endpoints"
    }
  end

  @doc """
  Returns a parameter definition for API key for sensitive endpoints in the request body.
  """
  @spec admin_api_key_request_body() :: OpenApiSpex.RequestBody.t()
  def admin_api_key_request_body do
    %OpenApiSpex.RequestBody{
      content: %{
        "application/json" => %OpenApiSpex.MediaType{
          schema: %OpenApiSpex.Schema{
            type: :object,
            properties: %{
              api_key: %Schema{type: :string}
            },
            required: [
              :api_key
            ]
          }
        }
      }
    }
  end

  @doc """
  Returns a parameter definition for reCAPTCHA response token.
  """
  @spec recaptcha_response_param() :: Parameter.t()
  def recaptcha_response_param do
    %Parameter{
      name: :recaptcha_response,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "reCAPTCHA response token"
    }
  end

  @doc """
  Returns a parameter definition for API key used in rate limiting.
  """
  @spec api_key_param() :: Parameter.t()
  def api_key_param do
    %Parameter{
      name: :apikey,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "API key for rate limiting or for sensitive endpoints"
    }
  end

  @doc """
  Returns a parameter definition for secret key used to access restricted resources.
  """
  @spec key_param() :: Parameter.t()
  def key_param do
    %Parameter{
      name: :key,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "Secret key for getting access to restricted resources"
    }
  end

  @doc """
  Returns a parameter definition for scale for hot contracts.
  """
  @spec hot_smart_contracts_scale_param() :: Parameter.t()
  def hot_smart_contracts_scale_param do
    %Parameter{
      in: :query,
      schema: %Schema{type: :string, enum: ["5m", "1h", "3h", "1d", "7d", "30d"], nullable: false},
      required: true,
      description:
        "Time scale for hot contracts aggregation (5m=5 minutes, 1h=1 hour, 3h=3 hours, 1d=1 day, 7d=7 days, 30d=30 days)",
      name: :scale
    }
  end

  @doc """
  Returns a parameter definition for MUD world address hash.
  """
  @spec world_param() :: Parameter.t()
  def world_param do
    %Parameter{
      name: :world,
      in: :path,
      schema: AddressHash,
      required: true,
      description: "MUD world address hash in the path"
    }
  end

  @doc """
  Returns a parameter definition for MUD system address hash.
  """
  @spec system_param() :: Parameter.t()
  def system_param do
    %Parameter{
      name: :system,
      in: :path,
      schema: AddressHash,
      required: true,
      description: "MUD system address hash in the path"
    }
  end

  @doc """
  Returns a parameter definition for MUD table ID.
  """
  @spec table_id_param() :: Parameter.t()
  def table_id_param do
    %Parameter{
      name: :table_id,
      in: :path,
      schema: FullHash,
      required: true,
      description: "MUD table ID in the path"
    }
  end

  @doc """
  Returns a parameter definition for MUD record ID.
  """
  @spec record_id_param() :: Parameter.t()
  def record_id_param do
    %Parameter{
      name: :record_id,
      in: :path,
      schema: HexString,
      required: true,
      description: "MUD record ID in the path"
    }
  end

  @doc """
  Returns a parameter definition for MUD tables namespace filter.
  """
  @spec filter_namespace_param() :: Parameter.t()
  def filter_namespace_param do
    %Parameter{
      name: :filter_namespace,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "Filter by namespace"
    }
  end

  @doc """
  Returns a parameter definition for MUD table records key0 filter.
  """
  @spec filter_key0_param() :: Parameter.t()
  def filter_key0_param do
    %Parameter{
      name: :filter_key0,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "Filter by key0"
    }
  end

  @doc """
  Returns a parameter definition for MUD table records key1 filter.
  """
  @spec filter_key1_param() :: Parameter.t()
  def filter_key1_param do
    %Parameter{
      name: :filter_key1,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "Filter by key1"
    }
  end

  @doc """
  Returns a parameter definition for a user operation hash in the path.
  """
  @spec operation_hash_param() :: Parameter.t()
  def operation_hash_param do
    %Parameter{
      name: :operation_hash_param,
      in: :path,
      schema: FullHash,
      required: true,
      description: "User operation hash in the path"
    }
  end

  @doc """
  Returns a list of base parameters (api_key and key).
  """
  @spec base_params() :: [Parameter.t()]
  def base_params do
    [api_key_param(), key_param()]
  end

  @doc """
  Returns a schema definition for paginated response.
  """
  @spec paginated_response(Keyword.t()) :: Schema.t()
  def paginated_response(options) do
    items_schema = Keyword.fetch!(options, :items)
    next_page_params_example = Keyword.fetch!(options, :next_page_params_example)

    %Schema{
      type: :object,
      properties: %{
        items: %Schema{type: :array, items: items_schema, nullable: false},
        next_page_params: %Schema{
          type: :object,
          nullable: true,
          example: next_page_params_example
        }
      },
      required: [:items, :next_page_params],
      nullable: false,
      additionalProperties: false
    }
  end

  @doc """
  Returns a schema definition for a simple message response.
  """
  @spec message_response_schema :: Schema.t()
  def message_response_schema do
    %Schema{
      type: :object,
      properties: %{
        message: %Schema{type: :string}
      },
      required: [:message],
      nullable: false,
      additionalProperties: false
    }
  end

  # `%Schema{anyOf: [%Schema{type: :integer}, EmptyString]}` is used because,
  # `allowEmptyValue: true` does not allow empty string for some reasons (at least in this case)

  @paging_params %{
    "block_number" => %Parameter{
      name: :block_number,
      in: :query,
      schema: %Schema{type: :integer, minimum: 0},
      required: false,
      description: "Block number for paging"
    },
    "block_number_nullable" => %Parameter{
      name: :block_number,
      in: :query,
      schema: %Schema{anyOf: [%Schema{type: :integer}, EmptyString, NullString]},
      required: false,
      description: "Block number for paging"
    },
    "block_number_no_casting" => %Parameter{
      name: :block_number,
      in: :query,
      schema: IntegerString,
      required: false,
      description: "Block number for paging"
    },
    "l1_block_number" => %Parameter{
      name: :l1_block_number,
      in: :query,
      schema: %Schema{type: :integer, minimum: 0},
      required: false,
      description: "L1 block number for paging"
    },
    "epoch_number" => %Parameter{
      name: :epoch_number,
      in: :query,
      schema: IntegerString,
      required: false,
      description: "Epoch number for paging"
    },
    "nonce" => %Parameter{
      name: :nonce,
      in: :query,
      schema: IntegerString,
      required: false,
      description: "Nonce for paging"
    },
    "index" => %Parameter{
      name: :index,
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "Transaction index for paging"
    },
    "index_nullable" => %Parameter{
      name: :index,
      in: :query,
      schema: %Schema{anyOf: [%Schema{type: :integer}, EmptyString, NullString]},
      required: false,
      description: "Transaction index for paging"
    },
    "block_index" => %Parameter{
      name: :block_index,
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "Block index for paging"
    },
    "inserted_at" => %Parameter{
      name: :inserted_at,
      in: :query,
      schema: %Schema{type: :string, format: :"date-time"},
      required: false,
      description: "Inserted at timestamp for paging (ISO8601)"
    },
    "hash" => %Parameter{
      name: :hash,
      in: :query,
      schema: FullHash,
      required: false,
      description: "Transaction hash for paging"
    },
    "transaction_hash" => %Parameter{
      name: :transaction_hash,
      in: :query,
      schema: FullHash,
      required: false,
      description: "Transaction hash for paging"
    },
    # TODO: consider refactoring, to avoid ambiguity with hash param (the same name)
    "address_hash" => %Parameter{
      name: :hash,
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Address hash for paging"
    },
    "address_hash_param" => %Parameter{
      name: :address_hash,
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Address hash for paging"
    },
    "contract_address_hash" => %Parameter{
      name: :contract_address_hash,
      in: :query,
      schema: AddressHashNullable,
      required: false,
      description: "Contract address hash for paging"
    },
    "value" => %Parameter{
      name: :value,
      in: :query,
      schema: IntegerString,
      required: false,
      description: "Transaction value for paging"
    },
    "fiat_value" => %Parameter{
      name: :fiat_value,
      in: :query,
      schema: %Schema{anyOf: [FloatString, EmptyString, NullString]},
      required: false,
      description: "Fiat value for paging"
    },
    "fee" => %Parameter{
      name: :fee,
      in: :query,
      schema: IntegerString,
      required: false,
      description: "Transaction fee for paging"
    },
    "items_count" => %Parameter{
      name: :items_count,
      in: :query,
      schema: %Schema{type: :integer, minimum: 1, maximum: 50},
      required: false,
      description: "Number of items returned per page"
    },
    "holders_count" => %Parameter{
      name: :holders_count,
      in: :query,
      schema: %Schema{anyOf: [IntegerString, EmptyString, NullString]},
      required: false,
      description: "Number of holders returned per page"
    },
    "is_name_null" => %Parameter{
      name: :is_name_null,
      in: :query,
      schema: %Schema{type: :boolean},
      required: false,
      description: "Is name null for paging"
    },
    "market_cap" => %Parameter{
      name: :market_cap,
      in: :query,
      schema: %Schema{anyOf: [FloatString, EmptyString, NullString]},
      required: false,
      description: "Market cap for paging"
    },
    "name" => %Parameter{
      name: :name,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "Name for paging"
    },
    "batch_log_index" => %Parameter{
      name: :batch_log_index,
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "Batch log index for paging"
    },
    "batch_block_hash" => %Parameter{
      name: :batch_block_hash,
      in: :query,
      schema: FullHash,
      required: false,
      description: "Batch block hash for paging"
    },
    "batch_transaction_hash" => %Parameter{
      name: :batch_transaction_hash,
      in: :query,
      schema: FullHash,
      required: false,
      description: "Batch transaction hash for paging"
    },
    "index_in_batch" => %Parameter{
      name: :index_in_batch,
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "Index in batch for paging"
    },
    "transaction_index" => %Parameter{
      name: :transaction_index,
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "Transaction index for paging"
    },
    "fiat_value_nullable" => %Parameter{
      name: :fiat_value,
      in: :query,
      schema: %Schema{anyOf: [FloatString, EmptyString, NullString]},
      required: false,
      description: "Fiat value for paging"
    },
    "id" => %Parameter{
      name: :id,
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "ID for paging"
    },
    "smart_contract_id" => %Parameter{
      name: :smart_contract_id,
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "Smart-contract ID for paging"
    },
    "fetched_coin_balance" => %Parameter{
      name: :fetched_coin_balance,
      in: :query,
      schema: IntegerStringNullable,
      required: false,
      description: "Fetched coin balance for paging"
    },
    "transactions_count" => %Parameter{
      name: :transactions_count,
      in: :query,
      schema: %Schema{anyOf: [%Schema{type: :integer}, EmptyString, NullString]},
      required: false,
      description: "Transactions count for paging"
    },
    "token_contract_address_hash" => %Parameter{
      name: :token_contract_address_hash,
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Token contract address hash for paging"
    },
    "token_id" => %Parameter{
      name: :token_id,
      in: :query,
      schema: IntegerStringNullable,
      required: false,
      description: "Token ID for paging"
    },
    # todo: eliminate in favour token_id
    "unique_token" => %Parameter{
      name: :unique_token,
      in: :query,
      schema: IntegerStringNullable,
      required: false,
      description: "Token ID for paging"
    },
    "token_type" => %Parameter{
      name: :token_type,
      in: :query,
      schema: TokenType,
      required: false,
      description: "Token type for paging"
    },
    "amount" => %Parameter{
      name: :amount,
      in: :query,
      schema: IntegerStringNullable,
      required: false,
      description: "Amount for paging"
    },
    "associated_account_address_hash" => %Parameter{
      name: :associated_account_address_hash,
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Associated account address hash for paging"
    },
    "type" => %Parameter{
      name: :type,
      in: :query,
      schema: CeloElectionRewardType.schema(),
      required: false,
      description: "Type for paging"
    },
    "filter" => %Parameter{
      name: :filter,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "Filter for paging"
    },
    "deposit_index" => %Parameter{
      name: :index,
      in: :query,
      schema: %Schema{type: :integer, minimum: 0, maximum: 9_223_372_036_854_775_807},
      required: false,
      description: "Deposit index for paging"
    },
    "total_gas_used" => %Parameter{
      name: :total_gas_used,
      in: :query,
      schema: %Schema{type: :integer, minimum: 0},
      required: false,
      description: "Total gas used for paging"
    },
    "contract_address_hash_not_nullable" => %Parameter{
      name: :contract_address_hash,
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Contract address hash for paging"
    },
    "transactions_count_positive" => %Parameter{
      name: :transactions_count,
      in: :query,
      schema: %Schema{type: :integer, minimum: 1},
      required: false,
      description: "Transactions count for paging"
    },
    "coin_balance" => %Parameter{
      name: :coin_balance,
      in: :query,
      schema: %Schema{anyOf: [%Schema{type: :integer}, EmptyString, NullString]},
      required: false,
      description: "Coin balance for paging"
    },
    # todo: remove in the future as this param is unused in the pagination of state changes
    "state_changes" => %Parameter{
      name: :state_changes,
      in: :query,
      schema: %Schema{type: :integer, nullable: true},
      required: false,
      description: "State changes for paging"
    },
    "world" => %Parameter{
      name: :world,
      in: :query,
      schema: AddressHash,
      required: false,
      description: "MUD world address hash for paging"
    },
    "table_id" => %Parameter{
      name: :table_id,
      in: :query,
      schema: FullHash,
      required: false,
      description: "MUD table ID for paging"
    },
    "key_bytes" => %Parameter{
      name: :key_bytes,
      in: :query,
      schema: HexString,
      required: false,
      description: "MUD record key_bytes for paging"
    },
    "key0" => %Parameter{
      name: :key0,
      in: :query,
      schema: FullHash,
      required: false,
      description: "MUD record key0 for paging"
    },
    "key1" => %Parameter{
      name: :key1,
      in: :query,
      schema: FullHash,
      required: false,
      description: "MUD record key1 for paging"
    },
    "page_size" => %Parameter{
      name: :page_size,
      in: :query,
      schema: %Schema{type: :integer, minimum: 1, maximum: 50},
      required: false,
      description: "Number of items returned per page"
    },
    "page_token" => %Parameter{
      name: :page_token,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "Page token for paging"
    }
  }

  @state_changes_paging_params %{
    # "items_count" is used for pagination for the list of transactions's state changes and it can be higher than 50.
    # Thus, we extracted it to a separate map.
    "items_count" => %Parameter{
      name: :items_count,
      in: :query,
      schema: %Schema{type: :integer, minimum: 1},
      required: false,
      description: "Cumulative number of items to skip for keyset-based pagination of state changes"
    },
    # todo: remove in the future as this param is unused in the pagination of state changes
    "state_changes" => %Parameter{
      name: :state_changes,
      in: :query,
      schema: %Schema{type: :string, nullable: true},
      required: false,
      description: "State changes for paging"
    }
  }

  @search_paging_params %{
    "q" => %Parameter{
      name: :q,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "Search query for paging"
    },
    "next_page_params_type" => %Parameter{
      name: :next_page_params_type,
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "Next page params type for paging"
    },
    "label" => %Parameter{
      name: :label,
      in: :query,
      schema: %Schema{type: :object},
      required: false,
      description: "Label for paging in the search results"
    },
    "token" => %Parameter{
      name: :token,
      in: :query,
      schema: %Schema{type: :object},
      required: false,
      description: "Token for paging in the search results"
    },
    "tac_operation" => %Parameter{
      name: :tac_operation,
      in: :query,
      schema: %Schema{type: :object},
      required: false,
      description: "TAC operation for paging in the search results"
    },
    "contract" => %Parameter{
      name: :contract,
      in: :query,
      schema: %Schema{type: :object},
      required: false,
      description: "Contract for paging in the search results"
    },
    "metadata_tag" => %Parameter{
      name: :metadata_tag,
      in: :query,
      schema: %Schema{type: :object},
      required: false,
      description: "Metadata tag for paging in the search results"
    },
    "block" => %Parameter{
      name: :block,
      in: :query,
      schema: %Schema{type: :object},
      required: false,
      description: "Block for paging in the search results"
    },
    "blob" => %Parameter{
      name: :blob,
      in: :query,
      schema: %Schema{type: :object},
      required: false,
      description: "Blob for paging in the search results"
    },
    "user_operation" => %Parameter{
      name: :user_operation,
      in: :query,
      schema: %Schema{type: :object},
      required: false,
      description: "User operation for paging in the search results"
    },
    "address" => %Parameter{
      name: :address,
      in: :query,
      schema: %Schema{type: :object},
      required: false,
      description: "Address for paging in the search results"
    },
    "ens_domain" => %Parameter{
      name: :ens_domain,
      in: :query,
      schema: %Schema{type: :object},
      required: false,
      description: "ENS domain for paging in the search results"
    }
  }

  @doc """
  Returns a list of paging parameters based on the provided field names.
  """
  @spec define_paging_params([String.t()]) :: [Parameter.t()]
  def define_paging_params(fields) do
    Enum.map(fields, fn field ->
      Map.get(@paging_params, field) || raise "Unknown paging param: #{field}"
    end)
  end

  @doc """
  Returns a list of pagination parameters for `/api/v2/transactions/:transaction_hash_param/state-changes` API endpoint
  """
  @spec define_state_changes_paging_params([String.t()]) :: [Parameter.t()]
  def define_state_changes_paging_params(fields) do
    Enum.map(fields, fn field ->
      Map.get(@state_changes_paging_params, field) || raise "Unknown paging param: #{field}"
    end)
  end

  @doc """
  Returns a list of pagination parameters for `/api/v2/search` API endpoint
  """
  @spec define_search_paging_params([String.t()]) :: [Parameter.t()]
  def define_search_paging_params(fields) do
    Enum.map(fields, fn field ->
      Map.get(@search_paging_params, field) || raise "Unknown paging param: #{field}"
    end)
  end

  @doc """
  Returns the list of allowed transaction type labels based on the configured chain type.
  """
  @spec allowed_transaction_types() :: [String.t()]
  def allowed_transaction_types, do: @allowed_transaction_types

  @doc """
  Returns the integer pattern.
  """
  @spec integer_pattern() :: Regex.t()
  def integer_pattern, do: @integer_pattern

  @doc """
  Returns the float pattern.
  """
  @spec float_pattern() :: Regex.t()
  def float_pattern, do: @float_pattern

  @doc """
  Returns the regex pattern for validating address hashes.
  """
  @spec address_hash_pattern() :: Regex.t()
  def address_hash_pattern, do: @address_hash_pattern

  @doc """
  Returns the regex pattern for validating full hashes.
  """
  @spec full_hash_pattern() :: Regex.t()
  def full_hash_pattern, do: @full_hash_pattern

  @doc """
  Returns the regex pattern for validating hex strings.
  """
  @spec hex_string_pattern() :: Regex.t()
  def hex_string_pattern, do: @hex_string_pattern
end
