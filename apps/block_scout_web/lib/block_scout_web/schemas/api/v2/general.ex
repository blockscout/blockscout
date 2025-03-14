defmodule BlockScoutWeb.Schemas.API.V2.General do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule AddressHash do
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{40})$", nullable: false})
  end

  defmodule AddressHashNullable do
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{40})$", nullable: true})
  end

  defmodule TransactionHash do
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{64})$", nullable: false})
  end

  defmodule TransactionHashNullable do
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{64})$", nullable: true})
  end

  defmodule ProxyType do
    OpenApiSpex.schema(%{
      type: :string,
      enum: [
        "eip1167",
        "eip1967",
        "eip1822",
        "eip930",
        "master_copy",
        "basic_implementation",
        "basic_get_implementation",
        "comptroller",
        "eip2535",
        "clone_with_immutable_arguments",
        "eip7702",
        "unknown"
      ],
      nullable: true
    })
  end

  defmodule Implementation do
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
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^([1-9][0-9]*|0)(\.[0-9]+)?$", nullable: true})
  end

  defmodule IntegerStringNullable do
    OpenApiSpex.schema(%{type: :string, pattern: ~r"^([1-9][0-9]*|0)$", nullable: true})
  end
end
