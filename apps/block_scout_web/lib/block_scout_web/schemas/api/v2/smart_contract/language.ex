defmodule BlockScoutWeb.Schemas.API.V2.SmartContract.Language.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.Helper

  @default_languages ["solidity", "vyper", "yul", "geas"]

  def chain_type_fields(schema) do
    case Application.get_env(:explorer, :chain_type) do
      :arbitrum ->
        schema
        |> Helper.extend_schema(enum: ["stylus_rust" | @default_languages])

      :zilliqa ->
        schema
        |> Helper.extend_schema(enum: ["scilla" | @default_languages])

      _ ->
        schema
        |> Helper.extend_schema(enum: @default_languages)
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.SmartContract.Language do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.SmartContract.Language.ChainTypeCustomizations

  OpenApiSpex.schema(%{type: :string} |> ChainTypeCustomizations.chain_type_fields())
end
