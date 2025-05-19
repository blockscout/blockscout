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

  defmodule TransactionHash do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{64})$", nullable: false})
  end

  defmodule TransactionHashNullable do
    @moduledoc false
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{64})$", nullable: true})
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

  defmodule Implementation do
    @moduledoc false
    OpenApiSpex.schema(%{
      description: "Proxy smart contract implementation",
      type: :object,
      properties: %{
        address: AddressHash,
        name: %Schema{type: :string, nullable: true}
      },
      required: [:address, :name]
    })
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
end
