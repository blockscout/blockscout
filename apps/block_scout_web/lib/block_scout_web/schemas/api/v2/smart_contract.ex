defmodule BlockScoutWeb.Schemas.API.V2.SmartContract.ChainTypeCustomizations do
  @moduledoc false
  import BlockScoutWeb.Schemas.API.V2.Address.ChainTypeCustomizations, only: [filecoin_robust_address_schema: 0]
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  @doc """
   Applies chain-specific field customizations to the given schema based on the configured chain type.

   ## Parameters
   - `schema`: The base schema map to be customized

   ## Returns
   - The schema map with chain-specific properties added based on the current chain type configuration
  """
  @spec chain_type_fields(map()) :: map()
  # credo:disable-for-next-line
  def chain_type_fields(schema) do
    case Application.get_env(:explorer, :chain_type) do
      :arbitrum ->
        schema
        |> Helper.extend_schema(
          properties: %{
            package_name: %Schema{type: :string, nullable: true},
            github_repository_metadata: %Schema{type: :object, nullable: true}
          },
          required: []
        )

      :zksync ->
        schema
        |> Helper.extend_schema(
          properties: %{
            zk_compiler_version: %Schema{type: :string, nullable: true}
          },
          required: []
        )

      :filecoin ->
        schema
        |> Helper.extend_schema(
          properties: %{
            verified_twin_filecoin_robust_address: filecoin_robust_address_schema()
          },
          required: []
        )

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.SmartContract do
  @moduledoc """
  OpenAPI schema for a smart contract response.

  Matches the API response shape returned by the `SmartContractController.smart_contract/2` action.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.SmartContract.ChainTypeCustomizations
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "Smart contract",
      type: :object,
      properties: %{
        file_path: %Schema{type: :string, nullable: true},
        creation_status: %Schema{type: :string, nullable: true},
        source_code: %Schema{type: :string, nullable: true},
        deployed_bytecode: %Schema{type: :string, nullable: true},
        address: BlockScoutWeb.Schemas.API.V2.Address,
        coin_balance: %Schema{type: :string, nullable: true},
        compiler_version: %Schema{type: :string, nullable: true},
        has_constructor_args: %Schema{type: :boolean, nullable: true},
        language: %Schema{type: :string, nullable: true},
        license_type: %Schema{type: :string, nullable: true},
        market_cap: %Schema{type: :string, nullable: true},
        optimization_enabled: %Schema{type: :boolean, nullable: true},
        reputation: %Schema{type: :string, nullable: true},
        transactions_count: %Schema{type: :integer, nullable: true},
        verified_at: %Schema{type: :string, format: :"date-time", nullable: true},
        verification_metadata: %Schema{type: :object, nullable: true},
        verified_twin_address_hash: %Schema{type: :string, nullable: true},
        compiler_settings: %Schema{type: :object, nullable: true},
        optimization_runs: %Schema{type: :integer, nullable: true},
        sourcify_repo_url: %Schema{type: :string, nullable: true},
        decoded_constructor_args: %Schema{
          type: :array,
          items: %Schema{type: :array, items: %Schema{anyOf: [%Schema{type: :object}, %Schema{type: :string}]}},
          nullable: true
        },
        is_verified_via_verifier_alliance: %Schema{type: :boolean, nullable: true},
        implementations: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              address_hash: General.AddressHash,
              name: %Schema{type: :string, nullable: true}
            }
          },
          nullable: true
        },
        proxy_type: %Schema{type: :string, nullable: true},
        external_libraries: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{name: %Schema{type: :string, nullable: true}, address_hash: General.AddressHash}
          },
          nullable: true
        },
        creation_bytecode: %Schema{type: :string, nullable: true},
        name: %Schema{type: :string, nullable: true},
        is_blueprint: %Schema{type: :boolean, nullable: true},
        is_verified: %Schema{type: :boolean, nullable: true},
        is_fully_verified: %Schema{type: :boolean, nullable: true},
        is_verified_via_eth_bytecode_db: %Schema{type: :boolean, nullable: true},
        evm_version: %Schema{type: :string, nullable: true},
        can_be_visualized_via_sol2uml: %Schema{type: :boolean, nullable: true},
        is_verified_via_sourcify: %Schema{type: :boolean, nullable: true},
        additional_sources: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{file_path: %Schema{type: :string}, source_code: %Schema{type: :string}}
          },
          nullable: true
        },
        certified: %Schema{type: :boolean},
        conflicting_implementations: %Schema{type: :array, nullable: true, items: %Schema{type: :object}},
        abi: %Schema{type: :array, nullable: true, items: %Schema{type: :object}},
        is_changed_bytecode: %Schema{type: :boolean, nullable: true},
        is_partially_verified: %Schema{type: :boolean, nullable: true},
        constructor_args: %Schema{type: :string, nullable: true}
      },
      required: [],
      additionalProperties: false
    }
    |> ChainTypeCustomizations.chain_type_fields()
  )
end
