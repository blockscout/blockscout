defmodule BlockScoutWeb.Schemas.API.V2.General do
  @moduledoc """
  This module defines the schema for general types used in the API.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Celo.ElectionReward.Type, as: CeloElectionRewardType
  alias BlockScoutWeb.Schemas.API.V2.Token.Type, as: TokenType
  alias OpenApiSpex.{Parameter, Schema}

  defmodule AddressHash do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{40})$", nullable: false})
  end

  defmodule AddressHashNullable do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{40})$", nullable: true})
  end

  defmodule FullHash do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{64})$", nullable: false})
  end

  defmodule FullHashNullable do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{64})$", nullable: true})
  end

  defmodule HexString do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]*)$", nullable: false})
  end

  defmodule HexStringNullable do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]*)$", nullable: true})
  end

  defmodule ProxyType do
    @moduledoc false
    alias Ecto.Enum
    alias Explorer.Chain.SmartContract.Proxy.Models.Implementation

    OpenApiSpex.schema(%{
      type: :string,
      enum: Enum.values(Implementation, :proxy_type),
      nullable: true
    })
  end

  defmodule Implementation.ChainTypeCustomizations do
    @moduledoc false
    alias OpenApiSpex.Schema

    @doc """
     Applies chain-specific field customizations to the given schema based on the configured chain type.

     ## Parameters
     - `schema`: The base schema map to be customized

     ## Returns
     - The schema map with chain-specific properties added based on the current chain type configuration
    """
    @spec chain_type_fields(map()) :: map()
    def chain_type_fields(schema) do
      case Application.get_env(:explorer, :chain_type) do
        :filecoin ->
          schema
          |> put_in(
            [:properties, :filecoin_robust_address],
            %Schema{
              type: :string,
              example: "f25nml2cfbljvn4goqtclhifepvfnicv6g7mfmmvq",
              nullable: true
            }
          )
          |> update_in([:required], &[:filecoin_robust_address | &1])

        _ ->
          schema
      end
    end
  end

  defmodule Implementation do
    @moduledoc false
    require OpenApiSpex

    alias Implementation.ChainTypeCustomizations

    OpenApiSpex.schema(
      %{
        description: "Proxy smart contract implementation",
        type: :object,
        properties: %{
          address_hash: AddressHash,
          name: %Schema{type: :string, nullable: true}
        },
        required: [:address_hash, :name]
      }
      |> ChainTypeCustomizations.chain_type_fields()
    )
  end

  defmodule Tag do
    @moduledoc false
    OpenApiSpex.schema(%{
      description: "Address tag struct",
      type: :object,
      properties: %{
        address_hash: AddressHash,
        display_name: %Schema{type: :string, nullable: false},
        label: %Schema{type: :string, nullable: false}
      },
      required: [:address_hash, :display_name, :label]
    })
  end

  defmodule WatchlistName do
    @moduledoc false
    OpenApiSpex.schema(%{
      description: "Watch list name struct",
      type: :object,
      properties: %{
        display_name: %Schema{type: :string, nullable: false},
        label: %Schema{type: :string, nullable: false}
      },
      required: [:display_name, :label]
    })
  end

  defmodule FloatString do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^([1-9][0-9]*|0)(\.[0-9]+)?$"})
  end

  defmodule FloatStringNullable do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^([1-9][0-9]*|0)(\.[0-9]+)?$", nullable: true})
  end

  defmodule IntegerStringNullable do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^-?([1-9][0-9]*|0)$", nullable: true})
  end

  defmodule IntegerString do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^-?([1-9][0-9]*|0)$", nullable: false})
  end

  defmodule URLNullable do
    @moduledoc false
    OpenApiSpex.schema(%{
      type: :string,
      format: :uri,
      example: "https://example.com",
      nullable: true
    })
  end

  defmodule Timestamp do
    @moduledoc false
    OpenApiSpex.schema(%{
      type: :string,
      format: :"date-time",
      nullable: false
    })
  end

  defmodule TimestampNullable do
    @moduledoc false
    OpenApiSpex.schema(%{
      type: :string,
      format: :"date-time",
      nullable: true
    })
  end

  defmodule DecodedInput do
    @moduledoc false
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        method_id: %Schema{type: :string, nullable: true},
        method_call: %Schema{type: :string, nullable: true},
        parameters: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              name: %Schema{type: :string, nullable: false},
              type: %Schema{type: :string, nullable: false},
              value: %Schema{
                anyOf: [%Schema{type: :object}, %Schema{type: :array}, %Schema{type: :string}],
                nullable: false
              }
            },
            nullable: false
          }
        }
      },
      required: [:method_id, :method_call, :parameters],
      nullable: false
    })
  end

  defmodule MethodNameNullable do
    @moduledoc false
    OpenApiSpex.schema(%{
      type: :string,
      nullable: true,
      example: "transfer",
      description: "Method name or hex method id"
    })
  end

  defmodule DecodedLogInput do
    @moduledoc false
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        method_id: %Schema{type: :string, nullable: true},
        method_call: %Schema{type: :string, nullable: true},
        parameters: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              name: %Schema{type: :string, nullable: false},
              type: %Schema{type: :string, nullable: false},
              indexed: %Schema{type: :boolean, nullable: false},
              value: %Schema{
                anyOf: [%Schema{type: :object}, %Schema{type: :array}, %Schema{type: :string}],
                nullable: false
              }
            },
            required: [:name, :type, :indexed, :value],
            nullable: false
          },
          nullable: false
        }
      },
      required: [:method_id, :method_call, :parameters],
      nullable: false
    })
  end

  defmodule EmptyString do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, minLength: 0, maxLength: 0})
  end

  defmodule NullString do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^null$"})
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
            pattern: ~r"^(ERC-20|ERC-721|ERC-1155|ERC-404)(,(ERC-20|ERC-721|ERC-1155|ERC-404))*$"
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
            pattern: ~r"^(ERC-721|ERC-1155|ERC-404)(,(ERC-721|ERC-1155|ERC-404))*$"
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
  Returns a parameter definition for API key used in rate limiting.
  """
  @spec api_key_param() :: Parameter.t()
  def api_key_param do
    %Parameter{
      in: :query,
      schema: %Schema{type: :string},
      required: false,
      description: "API key for rate limiting",
      name: :api_key
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
      nullable: false
    }
  end

  # `%Schema{anyOf: [%Schema{type: :integer}, EmptyString]}` is used because,
  # `allowEmptyValue: true` does not allow empty string for some reasons (at least in this case)

  @paging_params %{
    "block_number" => %Parameter{
      in: :query,
      schema: %Schema{type: :integer},
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
    "value" => %Parameter{
      in: :query,
      schema: IntegerString,
      required: false,
      description: "Transaction value for paging",
      name: :value
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
      schema: CeloElectionRewardType,
      required: false,
      description: "Type for paging",
      name: :type
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
end
