defmodule BlockScoutWeb.Schemas.API.V2.ChainTypeCustomizations do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  case @chain_type do
    :filecoin ->
      @filecoin_robust_address_schema %Schema{
        type: :string,
        example: "f25nml2cfbljvn4goqtclhifepvfnicv6g7mfmmvq",
        nullable: true
      }

      def token_chain_type_fields(schema) do
        schema
        |> put_in([:properties, :filecoin_robust_address], @filecoin_robust_address_schema)
        |> update_in([:required], &[:filecoin_robust_address | &1])
      end

      def address_chain_type_fields(schema) do
        schema
        |> put_in([:properties, :filecoin], %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, example: "f03248220", nullable: true},
            robust: %Schema{type: :string, example: "f25nml2cfbljvn4goqtclhifepvfnicv6g7mfmmvq", nullable: true},
            actor_type: %Schema{
              type: :string,
              enum: Ecto.Enum.values(Explorer.Chain.Address, :filecoin_actor_type),
              nullable: true
            }
          }
        })
      end

      def address_response_chain_type_fields(schema) do
        schema
        |> put_in([:properties, :creator_filecoin_robust_address], @filecoin_robust_address_schema)
        |> update_in([:required], &[:creator_filecoin_robust_address | &1])
      end

    :zilliqa ->
      def token_chain_type_fields(schema), do: schema

      def address_chain_type_fields(schema), do: schema

      def address_response_chain_type_fields(schema) do
        schema
        |> put_in([:properties, :is_scilla_contract], %Schema{type: :boolean, nullable: false})
      end

    _ ->
      def token_chain_type_fields(schema), do: schema

      def address_chain_type_fields(schema), do: schema

      def address_response_chain_type_fields(schema), do: schema
  end
end
