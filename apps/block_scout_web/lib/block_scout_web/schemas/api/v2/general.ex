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
  @token_type_pattern ~r/^\[?(ERC-20|ERC-721|ERC-1155|ERC-404)(,(ERC-20|ERC-721|ERC-1155|ERC-404))*\]?$/i
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
      required: true
    }
  end

  # todo: It should be removed when the frontend stops sending the address_id parameter with the request
  @doc """
  Returns a parameter definition for an address hash in the path.
  """
  @spec address_id_param() :: Parameter.t()
  def address_id_param do
    %Parameter{
      name: :address_id,
      in: :query,
      schema: AddressHash,
      required: false
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
      schema: %Schema{type: :string, nullable: true},
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
  Returns a parameter definition for a holder address hash in the query.
  """
  @spec holder_address_hash_param() :: Parameter.t()
  def holder_address_hash_param do
    %Parameter{
      name: :holder_address_hash,
      in: :query,
      schema: AddressHash,
      required: false
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
      schema: %Schema{anyOf: [%Schema{type: :integer}, FullHash]},
      required: true
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
      required: true
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
      * reorg - Only show reorgs
      * uncle - Only show uncle blocks
      * block - Only show main blocks
      If omitted, default value "block" is used.
      """
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
      schema: %Schema{type: :string, enum: @allowed_transaction_types},
      required: false,
      description: """
      Filter transactions by type:
      * coin_transfer - Only show coin transfer transactions
      * contract_call - Only show contract call transactions
      * contract_creation - Only show contract creation transactions
      * token_transfer - Only show token transfer transactions
      * token_creation - Only show token creation transactions
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

  @doc """
  Returns a parameter definition for filtering by token type.
  """
  @spec token_type_param() :: Parameter.t()
  def token_type_param do
    %Parameter{
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
      * ERC-20 - Fungible tokens
      * ERC-721 - Non-fungible tokens
      * ERC-1155 - Multi-token standard
      * ERC-404 - Hybrid fungible/non-fungible tokens

      Example: `ERC-20,ERC-721` to show both fungible and NFT transfers
      """,
      name: :type
    }
  end

  @doc """
  Returns a parameter definition for filtering by NFT token type.
  """
  @spec nft_token_type_param() :: Parameter.t()
  def nft_token_type_param do
    %Parameter{
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
      """,
      name: :type
    }
  end

  @doc """
  Returns a parameter definition for filtering logs by topic.
  """
  @spec topic_param() :: Parameter.t()
  def topic_param do
    %Parameter{
      in: :query,
      schema: HexString,
      required: false,
      description: "Filter logs by topic",
      name: :topic
    }
  end

  @doc """
  Returns a parameter definition for filtering token transfers by token contract address.
  """
  @spec token_filter_param() :: Parameter.t()
  def token_filter_param do
    %Parameter{
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Filter token transfers by token contract address.",
      name: :token
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
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "API key for rate limiting or for sensitive endpoints",
      name: :apikey
    }
  end

  @doc """
  Returns a parameter definition for secret key used to access restricted resources.
  """
  @spec key_param() :: Parameter.t()
  def key_param do
    %Parameter{
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "Secret key for getting access to restricted resources",
      name: :key
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
    title_prefix = Keyword.fetch!(options, :title_prefix)

    %Schema{
      title: "#{title_prefix}PaginatedResponse",
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

  # `%Schema{anyOf: [%Schema{type: :integer}, EmptyString]}` is used because,
  # `allowEmptyValue: true` does not allow empty string for some reasons (at least in this case)

  @paging_params %{
    "block_number" => %Parameter{
      in: :query,
      schema: %Schema{type: :integer, minimum: 0},
      required: false,
      description: "Block number for paging",
      name: :block_number
    },
    "block_number_nullable" => %Parameter{
      in: :query,
      schema: %Schema{anyOf: [%Schema{type: :integer}, EmptyString, NullString]},
      required: false,
      description: "Block number for paging",
      name: :block_number
    },
    "block_number_no_casting" => %Parameter{
      in: :query,
      schema: IntegerString,
      required: false,
      description: "Block number for paging",
      name: :block_number
    },
    "epoch_number" => %Parameter{
      in: :query,
      schema: IntegerString,
      required: false,
      description: "Epoch number for paging",
      name: :epoch_number
    },
    "index" => %Parameter{
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "Transaction index for paging",
      name: :index
    },
    "index_nullable" => %Parameter{
      in: :query,
      schema: %Schema{anyOf: [%Schema{type: :integer}, EmptyString, NullString]},
      required: false,
      description: "Transaction index for paging",
      name: :index
    },
    "block_index" => %Parameter{
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "Block index for paging",
      name: :block_index
    },
    "inserted_at" => %Parameter{
      in: :query,
      schema: %Schema{type: :string, format: :"date-time"},
      required: false,
      description: "Inserted at timestamp for paging (ISO8601)",
      name: :inserted_at
    },
    "hash" => %Parameter{
      in: :query,
      schema: FullHash,
      required: false,
      description: "Transaction hash for paging",
      name: :hash
    },
    # TODO: consider refactoring, to avoid ambiguity with hash param (the same name)
    "address_hash" => %Parameter{
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Address hash for paging",
      name: :hash
    },
    "address_hash_param" => %Parameter{
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Address hash for paging",
      name: :address_hash
    },
    "contract_address_hash" => %Parameter{
      in: :query,
      schema: AddressHashNullable,
      required: false,
      description: "Contract address hash for paging",
      name: :contract_address_hash
    },
    "value" => %Parameter{
      in: :query,
      schema: IntegerString,
      required: false,
      description: "Transaction value for paging",
      name: :value
    },
    "fiat_value" => %Parameter{
      in: :query,
      schema: %Schema{anyOf: [FloatString, EmptyString, NullString]},
      required: false,
      description: "Fiat value for paging",
      name: :fiat_value
    },
    "fee" => %Parameter{
      in: :query,
      schema: IntegerString,
      required: false,
      description: "Transaction fee for paging",
      name: :fee
    },
    "items_count" => %Parameter{
      in: :query,
      schema: %Schema{type: :integer, minimum: 1, maximum: 50},
      required: false,
      description: "Number of items returned per page",
      name: :items_count
    },
    "holders_count" => %Parameter{
      in: :query,
      schema: %Schema{anyOf: [IntegerString, EmptyString, NullString]},
      required: false,
      description: "Number of holders returned per page",
      name: :holders_count
    },
    "is_name_null" => %Parameter{
      in: :query,
      schema: %Schema{type: :boolean},
      required: false,
      description: "Is name null for paging",
      name: :is_name_null
    },
    "market_cap" => %Parameter{
      in: :query,
      schema: %Schema{anyOf: [FloatString, EmptyString, NullString]},
      required: false,
      description: "Market cap for paging",
      name: :market_cap
    },
    "name" => %Parameter{
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "Name for paging",
      name: :name
    },
    "batch_log_index" => %Parameter{
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "Batch log index for paging",
      name: :batch_log_index
    },
    "batch_block_hash" => %Parameter{
      in: :query,
      schema: FullHash,
      required: false,
      description: "Batch block hash for paging",
      name: :batch_block_hash
    },
    "batch_transaction_hash" => %Parameter{
      in: :query,
      schema: FullHash,
      required: false,
      description: "Batch transaction hash for paging",
      name: :batch_transaction_hash
    },
    "index_in_batch" => %Parameter{
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "Index in batch for paging",
      name: :index_in_batch
    },
    "transaction_index" => %Parameter{
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "Transaction index for paging",
      name: :transaction_index
    },
    "fiat_value_nullable" => %Parameter{
      in: :query,
      schema: %Schema{anyOf: [FloatString, EmptyString, NullString]},
      required: false,
      description: "Fiat value for paging",
      name: :fiat_value
    },
    "id" => %Parameter{
      in: :query,
      schema: %Schema{type: :integer},
      required: false,
      description: "ID for paging",
      name: :id
    },
    "fetched_coin_balance" => %Parameter{
      in: :query,
      schema: IntegerStringNullable,
      required: false,
      description: "Fetched coin balance for paging",
      name: :fetched_coin_balance
    },
    "transactions_count" => %Parameter{
      in: :query,
      schema: %Schema{anyOf: [%Schema{type: :integer}, EmptyString, NullString]},
      required: false,
      description: "Transactions count for paging",
      name: :transactions_count
    },
    "token_contract_address_hash" => %Parameter{
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Token contract address hash for paging",
      name: :token_contract_address_hash
    },
    "token_id" => %Parameter{
      in: :query,
      schema: IntegerStringNullable,
      required: false,
      description: "Token ID for paging",
      name: :token_id
    },
    # todo: eliminate in favour token_id
    "unique_token" => %Parameter{
      in: :query,
      schema: IntegerStringNullable,
      required: false,
      description: "Token ID for paging",
      name: :unique_token
    },
    "token_type" => %Parameter{
      in: :query,
      schema: TokenType,
      required: false,
      description: "Token type for paging",
      name: :token_type
    },
    "amount" => %Parameter{
      in: :query,
      schema: IntegerStringNullable,
      required: false,
      description: "Amount for paging",
      name: :amount
    },
    "associated_account_address_hash" => %Parameter{
      in: :query,
      schema: AddressHash,
      required: false,
      description: "Associated account address hash for paging",
      name: :associated_account_address_hash
    },
    "type" => %Parameter{
      in: :query,
      schema: CeloElectionRewardType.schema(),
      required: false,
      description: "Type for paging",
      name: :type
    },
    "deposit_index" => %Parameter{
      in: :query,
      schema: %Schema{type: :integer, minimum: 0, maximum: 9_223_372_036_854_775_807},
      required: false,
      description: "Deposit index for paging",
      name: :index
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
