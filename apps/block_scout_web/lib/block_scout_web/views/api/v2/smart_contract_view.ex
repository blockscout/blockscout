defmodule BlockScoutWeb.API.V2.SmartContractView do
  use BlockScoutWeb, :view
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import Explorer.SmartContract.Reader, only: [zip_tuple_values_with_types: 2]

  alias ABI.FunctionSelector
  alias BlockScoutWeb.API.V2.Helper, as: APIV2Helper
  alias BlockScoutWeb.API.V2.TransactionView
  alias BlockScoutWeb.{AddressContractView, SmartContractView}
  alias Ecto.Changeset
  alias Explorer.Chain
  alias Explorer.Chain.{Address, SmartContract, SmartContractAdditionalSource}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Visualize.Sol2uml

  require Logger

  @api_true [api?: true]

  def render("smart_contracts.json", %{addresses: addresses, next_page_params: next_page_params}) do
    %{
      "items" => Enum.map(addresses, &prepare_smart_contract_address_for_list/1),
      "next_page_params" => next_page_params
    }
  end

  def render("smart_contract.json", %{address: address, conn: conn}) do
    prepare_smart_contract(address, conn)
  end

  def render("read_functions.json", %{functions: functions}) do
    Enum.map(functions, &prepare_read_function/1)
  end

  def render("function_response.json", %{output: output, names: names, contract_address_hash: contract_address_hash}) do
    prepare_function_response(output, names, contract_address_hash)
  end

  def render("changeset_errors.json", %{changeset: changeset}) do
    Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  def render("audit_reports.json", %{reports: reports}) do
    %{"items" => Enum.map(reports, &prepare_audit_report/1), "next_page_params" => nil}
  end

  defp prepare_audit_report(report) do
    %{
      "audit_company_name" => report.audit_company_name,
      "audit_report_url" => report.audit_report_url,
      "audit_publish_date" => report.audit_publish_date
    }
  end

  def prepare_function_response(outputs, names, contract_address_hash) do
    case outputs do
      {:error, %{code: code, message: message, data: _data} = error} ->
        revert_reason = Chain.parse_revert_reason_from_error(error)

        case SmartContractView.decode_revert_reason(contract_address_hash, revert_reason, @api_true) do
          {:ok, method_id, text, mapping} ->
            %{
              result:
                render(TransactionView, "decoded_input.json",
                  method_id: method_id,
                  text: text,
                  mapping: mapping,
                  error?: true
                ),
              is_error: true
            }

          {:error, _contract_verified, []} ->
            %{
              result:
                Map.merge(render(TransactionView, "revert_reason.json", raw: revert_reason), %{
                  code: code,
                  message: message
                }),
              is_error: true
            }

          {:error, _contract_verified, candidates} ->
            {:ok, method_id, text, mapping} = Enum.at(candidates, 0)

            %{
              result:
                render(TransactionView, "decoded_input.json",
                  method_id: method_id,
                  text: text,
                  mapping: mapping,
                  error?: true
                ),
              is_error: true
            }

          _ ->
            %{
              result:
                Map.merge(render(TransactionView, "revert_reason.json", raw: revert_reason), %{
                  code: code,
                  message: message
                }),
              is_error: true
            }
        end

      {:error, %{code: code, message: message}} ->
        %{result: %{code: code, message: message}, is_error: true}

      {:error, error} ->
        %{result: %{error: error}, is_error: true}

      _ ->
        %{result: %{output: Enum.map(outputs, &render_json/1), names: names}, is_error: false}
    end
  end

  def prepare_read_function(function) do
    case function["outputs"] do
      {:error, text_error} ->
        function
        |> Map.put("error", text_error)
        |> Map.replace("outputs", function["abi_outputs"])
        |> Map.drop(["abi_outputs"])

      nil ->
        function

      _ ->
        result =
          function
          |> Map.drop(["abi_outputs"])

        outputs = result["outputs"] |> Enum.map(&prepare_output/1)
        Map.replace(result, "outputs", outputs)
    end
  end

  defp prepare_output(%{"type" => type, "value" => value} = output) do
    Map.replace(output, "value", render_json(value, type))
  end

  defp prepare_output(output), do: output

  # credo:disable-for-next-line
  defp prepare_smart_contract(
         %Address{smart_contract: %SmartContract{} = smart_contract, proxy_implementations: implementations} = address,
         _conn
       ) do
    smart_contract_verified = APIV2Helper.smart_contract_verified?(address)

    bytecode_twin_contract =
      if smart_contract_verified,
        do: nil,
        else: address.smart_contract

    additional_sources =
      get_additional_sources(
        smart_contract,
        smart_contract_verified,
        bytecode_twin_contract
      )

    fully_verified = SmartContract.verified_with_full_match?(address.hash, @api_true)
    visualize_sol2uml_enabled = Sol2uml.enabled?()

    proxy_type = implementations && implementations.proxy_type

    minimal_proxy? = proxy_type in ["eip1167", "clone_with_immutable_arguments", "erc7760"]

    target_contract =
      if smart_contract_verified, do: smart_contract, else: bytecode_twin_contract

    # don't return verified_bytecode_twin_address_hash if smart contract is verified or minimal proxy
    verified_bytecode_twin_address_hash =
      (!smart_contract_verified && !minimal_proxy? &&
         bytecode_twin_contract && Address.checksum(bytecode_twin_contract.verified_bytecode_twin_address_hash)) || nil

    smart_contract_verified_via_sourcify = smart_contract_verified && smart_contract.verified_via_sourcify

    %{
      "verified_twin_address_hash" => verified_bytecode_twin_address_hash,
      "is_verified" => smart_contract_verified,
      "is_changed_bytecode" => smart_contract_verified && smart_contract.is_changed_bytecode,
      "is_partially_verified" => smart_contract_verified && smart_contract.partially_verified,
      "is_fully_verified" => fully_verified,
      "is_verified_via_sourcify" => smart_contract_verified_via_sourcify,
      "is_verified_via_eth_bytecode_db" => smart_contract.verified_via_eth_bytecode_db,
      "is_verified_via_verifier_alliance" => smart_contract.verified_via_verifier_alliance,
      "proxy_type" => proxy_type,
      "implementations" => Proxy.proxy_object_info(implementations),
      "sourcify_repo_url" =>
        if(smart_contract_verified_via_sourcify,
          do: AddressContractView.sourcify_repo_url(address.hash, smart_contract.partially_verified)
        ),
      "can_be_visualized_via_sol2uml" =>
        visualize_sol2uml_enabled && target_contract && SmartContract.language(target_contract) == :solidity,
      "name" => target_contract && target_contract.name,
      "compiler_version" => target_contract && target_contract.compiler_version,
      "optimization_enabled" => target_contract && target_contract.optimization,
      "optimization_runs" => target_contract && target_contract.optimization_runs,
      "evm_version" => target_contract && target_contract.evm_version,
      "verified_at" => target_contract && target_contract.inserted_at,
      "abi" => target_contract && target_contract.abi,
      "source_code" => target_contract && target_contract.contract_source_code,
      "file_path" => target_contract && target_contract.file_path,
      "additional_sources" => Enum.map(additional_sources, &prepare_additional_source/1),
      "compiler_settings" => target_contract && target_contract.compiler_settings,
      "external_libraries" => (target_contract && prepare_external_libraries(target_contract.external_libraries)) || [],
      "constructor_args" => if(smart_contract_verified, do: smart_contract.constructor_arguments),
      "decoded_constructor_args" =>
        if(smart_contract_verified,
          do: SmartContract.format_constructor_arguments(smart_contract.abi, smart_contract.constructor_arguments)
        ),
      "language" => SmartContract.language(smart_contract),
      "license_type" => smart_contract.license_type,
      "certified" => if(smart_contract.certified, do: smart_contract.certified, else: false),
      "is_blueprint" => if(smart_contract.is_blueprint, do: smart_contract.is_blueprint, else: false)
    }
    |> Map.merge(bytecode_info(address))
    |> chain_type_fields(
      %{
        address_hash: verified_bytecode_twin_address_hash,
        field_prefix: "verified_twin",
        target_contract: target_contract
      },
      true
    )
  end

  defp prepare_smart_contract(%Address{proxy_implementations: implementations} = address, _conn) do
    %{
      "proxy_type" => implementations && implementations.proxy_type,
      "implementations" => Proxy.proxy_object_info(implementations)
    }
    |> Map.merge(bytecode_info(address))
  end

  @doc """
  Returns additional sources of the smart-contract or from its bytecode twin
  """
  @spec get_additional_sources(SmartContract.t(), boolean, SmartContract.t() | nil) ::
          [SmartContractAdditionalSource.t()]
  def get_additional_sources(%{smart_contract_additional_sources: original_smart_contract_additional_sources}, true, _)
      when is_list(original_smart_contract_additional_sources) do
    original_smart_contract_additional_sources
  end

  def get_additional_sources(_, false, %{
        smart_contract_additional_sources: bytecode_twin_smart_contract_additional_sources
      })
      when is_list(bytecode_twin_smart_contract_additional_sources) do
    bytecode_twin_smart_contract_additional_sources
  end

  def get_additional_sources(_smart_contract, _smart_contract_verified, _bytecode_twin_contract), do: []

  defp bytecode_info(address) do
    case AddressContractView.contract_creation_code(address) do
      {:selfdestructed, init} ->
        %{
          "deployed_bytecode" => nil,
          "creation_bytecode" => init,
          "creation_status" => "selfdestructed"
        }

      {:failed, creation_code} ->
        %{
          "deployed_bytecode" => "0x",
          "creation_bytecode" => creation_code,
          "creation_status" => "failed"
        }

      {:ok, contract_code} ->
        %{
          "deployed_bytecode" => contract_code,
          "creation_bytecode" => AddressContractView.creation_code(address),
          "creation_status" => "success"
        }
    end
  end

  defp prepare_external_libraries(libraries) when is_list(libraries) do
    Enum.map(libraries, fn %Explorer.Chain.SmartContract.ExternalLibrary{name: name, address_hash: address_hash} ->
      {:ok, hash} = Chain.string_to_address_hash(address_hash)

      %{name: name, address_hash: Address.checksum(hash)}
    end)
  end

  defp prepare_additional_source(source) do
    %{
      "source_code" => source.contract_source_code,
      "file_path" => source.file_name
    }
  end

  defp prepare_smart_contract_address_for_list(
         %Address{
           smart_contract: %SmartContract{} = smart_contract,
           token: token
         } = address
       ) do
    smart_contract_info =
      %{
        "address" => APIV2Helper.address_with_info(nil, address, address.hash, false),
        "compiler_version" => smart_contract.compiler_version,
        "optimization_enabled" => smart_contract.optimization,
        "transactions_count" => address.transactions_count,
        # todo: It should be removed in favour `transactions_count` property with the next release after 8.0.0
        "transaction_count" => address.transactions_count,
        "language" => SmartContract.language(smart_contract),
        "verified_at" => smart_contract.inserted_at,
        "market_cap" => token && token.circulating_market_cap,
        "has_constructor_args" => !is_nil(smart_contract.constructor_arguments),
        "coin_balance" => if(address.fetched_coin_balance, do: address.fetched_coin_balance.value),
        "license_type" => smart_contract.license_type,
        "certified" => if(smart_contract.certified, do: smart_contract.certified, else: false)
      }

    smart_contract_info
    |> chain_type_fields(
      %{target_contract: smart_contract},
      false
    )
  end

  def render_json(%{"type" => type, "value" => value}) do
    %{"type" => type, "value" => render_json(value, type)}
  end

  def render_json(value, type) when is_tuple(value) do
    value
    |> zip_tuple_values_with_types(type)
    |> Enum.map(fn {type, value} ->
      render_json(value, type)
    end)
  end

  def render_json(value, type) when is_list(value) and is_tuple(type) do
    item_type =
      case type do
        {:array, item_type, _} -> item_type
        {:array, item_type} -> item_type
      end

    value |> Enum.map(&render_json(&1, item_type))
  end

  def render_json(value, type) when is_list(value) and not is_tuple(type) do
    sanitized_type =
      case type do
        "tuple[" <> rest ->
          # we need to convert tuple[...][] or tuple[...][n] into (...)[] or (...)[n]
          # before sending it to the `FunctionSelector.decode_type/1`. See https://github.com/poanetwork/ex_abi/issues/168.
          tuple_item_types =
            rest
            |> String.split("]")
            |> Enum.slice(0..-3//1)
            |> Enum.join("]")

          array_str = "[" <> (rest |> String.split("[") |> List.last())

          "(" <> tuple_item_types <> ")" <> array_str

        _ ->
          type
      end

    item_type =
      case FunctionSelector.decode_type(sanitized_type) do
        {:array, item_type, _} -> item_type
        {:array, item_type} -> item_type
      end

    value |> Enum.map(&render_json(&1, item_type))
  end

  def render_json(value, type) when type in [:address, "address", "address payable"] do
    SmartContractView.cast_address(value)
  end

  def render_json(value, type) when type in [:string, "string"] do
    to_string(value)
  end

  def render_json(value, _type) do
    to_string(value)
  end

  case @chain_type do
    :filecoin ->
      defp chain_type_fields(result, params, true) do
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        BlockScoutWeb.API.V2.FilecoinView.preload_and_put_filecoin_robust_address(result, params)
      end

      defp chain_type_fields(result, _params, false),
        do: result

    :arbitrum ->
      defp chain_type_fields(result, %{target_contract: target_contract}, _single?) do
        result
        |> Map.put("package_name", target_contract.package_name)
        |> Map.put("github_repository_metadata", target_contract.github_repository_metadata)
      end

    :zksync ->
      defp chain_type_fields(result, %{target_contract: target_contract}, _single?) do
        result
        |> Map.put("zk_compiler_version", target_contract.zk_compiler_version)
      end

    _ ->
      defp chain_type_fields(result, _params, _single?) do
        result
      end
  end
end
