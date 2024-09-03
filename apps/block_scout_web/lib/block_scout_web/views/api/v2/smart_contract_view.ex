defmodule BlockScoutWeb.API.V2.SmartContractView do
  use BlockScoutWeb, :view

  import Explorer.Helper, only: [decode_data: 2]
  import Explorer.SmartContract.Reader, only: [zip_tuple_values_with_types: 2]

  alias ABI.FunctionSelector
  alias BlockScoutWeb.API.V2.{Helper, TransactionView}
  alias BlockScoutWeb.SmartContractView
  alias BlockScoutWeb.{ABIEncodedValueView, AddressContractView, AddressView}
  alias Ecto.Changeset
  alias Explorer.Chain
  alias Explorer.Chain.{Address, SmartContract, SmartContractAdditionalSource}
  alias Explorer.SmartContract.Helper, as: SmartContractHelper
  alias Explorer.Visualize.Sol2uml

  require Logger

  @api_true [api?: true]
  # Option to skip fetching implementation from the node,
  # when checking, if smart-contract is proxy. It is used in smart contract view
  # to prevent double request to the JSON RPC node.
  @skip_implementation_fetch_true [skip_implementation_fetch?: true]

  def render("smart_contracts.json", %{smart_contracts: smart_contracts, next_page_params: next_page_params}) do
    %{"items" => Enum.map(smart_contracts, &prepare_smart_contract_for_list/1), "next_page_params" => next_page_params}
  end

  def render("smart_contract.json", %{
        address: address,
        implementations: implementations,
        proxy_type: proxy_type,
        conn: conn
      }) do
    prepare_smart_contract(address, implementations, proxy_type, conn)
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
  def prepare_smart_contract(
        %Address{smart_contract: %SmartContract{} = smart_contract} = address,
        implementations,
        proxy_type,
        conn
      ) do
    bytecode_twin = SmartContract.get_address_verified_bytecode_twin_contract(address.hash, @api_true)
    minimal_proxy_address_hash = address.implementation
    bytecode_twin_contract = bytecode_twin.verified_contract
    smart_contract_verified = AddressView.smart_contract_verified?(address)
    fully_verified = SmartContract.verified_with_full_match?(address.hash, @api_true)
    write_methods? = AddressView.smart_contract_with_write_functions?(address)

    is_proxy = SmartContractHelper.address_is_proxy?(address, Keyword.merge(@api_true, @skip_implementation_fetch_true))

    read_custom_abi? = AddressView.has_address_custom_abi_with_read_functions?(conn, address.hash)
    write_custom_abi? = AddressView.has_address_custom_abi_with_write_functions?(conn, address.hash)

    additional_sources =
      get_additional_sources(
        smart_contract,
        smart_contract_verified,
        bytecode_twin_contract
      )

    visualize_sol2uml_enabled = Sol2uml.enabled?()

    target_contract =
      if smart_contract_verified, do: smart_contract, else: bytecode_twin_contract

    %{
      "verified_twin_address_hash" =>
        bytecode_twin_contract &&
          Address.checksum(bytecode_twin_contract.address_hash),
      "is_verified" => smart_contract_verified,
      "is_changed_bytecode" => smart_contract_verified && smart_contract.is_changed_bytecode,
      "is_partially_verified" => smart_contract.partially_verified && smart_contract_verified,
      "is_fully_verified" => fully_verified,
      "is_verified_via_sourcify" => smart_contract.verified_via_sourcify && smart_contract_verified,
      "is_verified_via_eth_bytecode_db" => smart_contract.verified_via_eth_bytecode_db,
      "is_verified_via_verifier_alliance" => smart_contract.verified_via_verifier_alliance,
      "is_vyper_contract" => target_contract && target_contract.is_vyper_contract,
      "has_custom_methods_read" => read_custom_abi?,
      "has_custom_methods_write" => write_custom_abi?,
      "has_methods_read" => AddressView.smart_contract_with_read_only_functions?(address),
      "has_methods_write" => write_methods?,
      "has_methods_read_proxy" => is_proxy,
      "has_methods_write_proxy" => is_proxy && write_methods?,
      # todo: remove this property once frontend is bound to "implementations"
      "minimal_proxy_address_hash" =>
        minimal_proxy_address_hash && Address.checksum(minimal_proxy_address_hash.address_hash),
      "proxy_type" => proxy_type,
      "implementations" => implementations,
      "sourcify_repo_url" =>
        if(smart_contract.verified_via_sourcify && smart_contract_verified,
          do: AddressContractView.sourcify_repo_url(address.hash, smart_contract.partially_verified)
        ),
      "can_be_visualized_via_sol2uml" =>
        visualize_sol2uml_enabled && target_contract && !target_contract.is_vyper_contract &&
          !is_nil(target_contract.abi),
      "name" => target_contract && target_contract.name,
      "compiler_version" => target_contract && target_contract.compiler_version,
      "optimization_enabled" => target_contract && target_contract.optimization,
      "optimization_runs" => target_contract && target_contract.optimization_runs,
      "evm_version" => target_contract && target_contract.evm_version,
      "verified_at" => target_contract && target_contract.inserted_at,
      "abi" => target_contract && target_contract.abi,
      "source_code" => target_contract && target_contract.contract_source_code,
      "file_path" => target_contract && target_contract.file_path,
      "additional_sources" =>
        (is_list(additional_sources) && Enum.map(additional_sources, &prepare_additional_source/1)) || [],
      "compiler_settings" => target_contract && target_contract.compiler_settings,
      "external_libraries" => (target_contract && prepare_external_libraries(target_contract.external_libraries)) || [],
      "constructor_args" => if(smart_contract_verified, do: target_contract && target_contract.constructor_arguments),
      "decoded_constructor_args" =>
        if(smart_contract_verified,
          do:
            target_contract && format_constructor_arguments(target_contract.abi, target_contract.constructor_arguments)
        ),
      "language" => smart_contract_language(smart_contract),
      "license_type" => smart_contract.license_type,
      "certified" => if(smart_contract.certified, do: smart_contract.certified, else: false),
      "is_blueprint" => if(smart_contract.is_blueprint, do: smart_contract.is_blueprint, else: false)
    }
    |> Map.merge(bytecode_info(address))
    |> add_zksync_info(target_contract)
  end

  def prepare_smart_contract(address, implementations, proxy_type, conn) do
    read_custom_abi? = AddressView.has_address_custom_abi_with_read_functions?(conn, address.hash)
    write_custom_abi? = AddressView.has_address_custom_abi_with_write_functions?(conn, address.hash)

    %{
      "has_custom_methods_read" => read_custom_abi?,
      "has_custom_methods_write" => write_custom_abi?,
      "proxy_type" => proxy_type,
      "implementations" => implementations
    }
    |> Map.merge(bytecode_info(address))
  end

  @doc """
  Returns additional sources of the smart-contract or from its bytecode twin
  """
  @spec get_additional_sources(SmartContract.t(), boolean, SmartContract.t() | nil) ::
          [SmartContractAdditionalSource.t()] | nil
  def get_additional_sources(smart_contract, smart_contract_verified, bytecode_twin_contract) do
    cond do
      smart_contract_verified && is_list(smart_contract.smart_contract_additional_sources) &&
          !Enum.empty?(smart_contract.smart_contract_additional_sources) ->
        smart_contract.smart_contract_additional_sources

      !is_nil(bytecode_twin_contract) ->
        bytecode_twin_contract.smart_contract_additional_sources

      true ->
        []
    end
  end

  defp bytecode_info(address) do
    case AddressContractView.contract_creation_code(address) do
      {:selfdestructed, init} ->
        %{
          "is_self_destructed" => true,
          "deployed_bytecode" => nil,
          "creation_bytecode" => init
        }

      {:ok, contract_code} ->
        %{
          "is_self_destructed" => false,
          "deployed_bytecode" => contract_code,
          "creation_bytecode" => AddressContractView.creation_code(address)
        }
    end
  end

  defp add_zksync_info(smart_contract_info, target_contract) do
    if Application.get_env(:explorer, :chain_type) == :zksync do
      Map.merge(smart_contract_info, %{
        "zk_compiler_version" => target_contract.zk_compiler_version
      })
    else
      smart_contract_info
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

  def format_constructor_arguments(abi, constructor_arguments)
      when not is_nil(abi) and not is_nil(constructor_arguments) do
    constructor_abi = Enum.find(abi, fn el -> el["type"] == "constructor" && el["inputs"] != [] end)

    input_types = Enum.map(constructor_abi["inputs"], &FunctionSelector.parse_specification_type/1)

    result =
      constructor_arguments
      |> decode_data(input_types)
      |> Enum.zip(constructor_abi["inputs"])
      |> Enum.map(fn {value, %{"type" => type} = input_arg} ->
        [ABIEncodedValueView.value_json(type, value), input_arg]
      end)

    result
  rescue
    exception ->
      Logger.warning(fn ->
        [
          "Error formatting constructor arguments for abi: #{inspect(abi)}, args: #{inspect(constructor_arguments)}: ",
          Exception.format(:error, exception)
        ]
      end)

      nil
  end

  def format_constructor_arguments(_abi, _constructor_arguments), do: nil

  defp prepare_smart_contract_for_list(%SmartContract{} = smart_contract) do
    token = smart_contract.address.token

    smart_contract_info =
      %{
        "address" =>
          Helper.address_with_info(
            nil,
            %Address{smart_contract.address | smart_contract: smart_contract},
            smart_contract.address.hash,
            false
          ),
        "compiler_version" => smart_contract.compiler_version,
        "optimization_enabled" => smart_contract.optimization,
        "tx_count" => smart_contract.address.transactions_count,
        "language" => smart_contract_language(smart_contract),
        "verified_at" => smart_contract.inserted_at,
        "market_cap" => token && token.circulating_market_cap,
        "has_constructor_args" => !is_nil(smart_contract.constructor_arguments),
        "coin_balance" =>
          if(smart_contract.address.fetched_coin_balance, do: smart_contract.address.fetched_coin_balance.value),
        "license_type" => smart_contract.license_type,
        "certified" => if(smart_contract.certified, do: smart_contract.certified, else: false)
      }

    smart_contract_info
    |> add_zksync_info(smart_contract)
  end

  defp smart_contract_language(smart_contract) do
    cond do
      smart_contract.is_vyper_contract ->
        "vyper"

      is_nil(smart_contract.abi) ->
        "yul"

      true ->
        "solidity"
    end
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
          # before sending it to the `FunctionSelector.decode_type/1. See https://github.com/poanetwork/ex_abi/issues/168.
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
end
