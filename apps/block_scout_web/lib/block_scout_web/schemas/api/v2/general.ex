defmodule BlockScoutWeb.Schemas.API.V2.General do
  @moduledoc """
  This module defines the schema for general types used in the API.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

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
            |> update_in([:required], &[:filecoin_robust_address | &1])
          )

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

  defmodule FloatStringNullable do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^([1-9][0-9]*|0)(\.[0-9]+)?$", nullable: true})
  end

  defmodule IntegerStringNullable do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^([1-9][0-9]*|0)$", nullable: true})
  end

  defmodule IntegerString do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^([1-9][0-9]*|0)$", nullable: false})
  end

  defmodule URLNullable do
    @moduledoc false
    OpenApiSpex.schema(%{
      type: :string,
      pattern:
        ~r"/^https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)$/",
      example: "https://example.com",
      nullable: true
    })
  end

  defmodule URLWithIPFSNullable do
    @moduledoc false
    OpenApiSpex.schema(%{
      type: :string,
      pattern:
        ~r"/^(https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)|ipfs:\/\/[a-zA-Z0-9\/]+)$/",
      example: "https://example.com",
      nullable: true
    })
  end

  defmodule Timestamp do
    @moduledoc false
    OpenApiSpex.schema(%{
      type: :string,
      pattern: ~r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$",
      example: "2025-05-20T16:27:47.000000Z",
      nullable: false
    })
  end

  defmodule TimestampNullable do
    @moduledoc false
    OpenApiSpex.schema(%{
      type: :string,
      pattern: ~r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$",
      example: "2025-05-20T16:27:47.000000Z",
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
                oneOf: [%Schema{type: :object}, %Schema{type: :array}, %Schema{type: :string}],
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

  def address_hash_param do
    {:address_hash_param,
     [
       in: :path,
       type: AddressHash,
       required: true
     ]}
  end

  def direction_filter_param do
    {:filter,
     [
       in: :query,
       schema: %Schema{type: :string, enum: ["to", "from"]},
       required: false,
       description: """
       Filter transactions by direction:
       * to - Only show transactions sent to this address
       * from - Only show transactions sent from this address
       If omitted, all transactions involving the address are returned.
       """
     ]}
  end

  def sorting_params do
    {:sort,
     [
       in: :query,
       schema: %Schema{
         type: :string,
         enum: ["block_number", "value", "fee"]
       },
       required: false,
       description: """
       Sort transactions by:
       * block_number - Sort by block number
       * value - Sort by transaction value
       * fee - Sort by transaction fee
       Should be used together with `order` parameter.
       """
     ]}
  end

  def order_params do
    {:order,
     [
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
       """
     ]}
  end

  def token_transfer_type_param do
    {:type,
     [
       in: :query,
       schema: %Schema{
         type: :string,
         pattern: ~r"^(ERC-20|ERC-721|ERC-1155|ERC-404)(,(ERC-20|ERC-721|ERC-1155|ERC-404))*$"
       },
       required: false,
       description: """
       Filter by token type. Comma-separated list of:
       * ERC-20 - Fungible tokens
       * ERC-721 - Non-fungible tokens
       * ERC-1155 - Multi-token standard
       * ERC-404 - ERC-404 tokens

       Example: `ERC-20,ERC-721` to show both fungible and NFT transfers
       """
     ]}
  end

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
      nullable: false
    }
  end
end
