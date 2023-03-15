defmodule BlockScoutWeb.API.V2.SmartContractView do
  use BlockScoutWeb, :view

  alias ABI.FunctionSelector
  alias BlockScoutWeb.API.V2.{Helper, TransactionView}
  alias BlockScoutWeb.SmartContractView
  alias BlockScoutWeb.{ABIEncodedValueView, AddressContractView, AddressView}
  alias Ecto.Changeset
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.ExchangeRates.Token
  alias Explorer.Visualize.Sol2uml

  require Logger

  @api_true [api?: true]

  def render("smart_contracts.json", %{smart_contracts: smart_contracts, next_page_params: next_page_params}) do
    %{"items" => Enum.map(smart_contracts, &prepare_smart_contract_for_list/1), "next_page_params" => next_page_params}
  end

  def render("smart_contract.json", %{address: address}) do
    prepare_smart_contract(address)
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

  def prepare_function_response(outputs, names, contract_address_hash) do
    case outputs do
      {:error, %{code: code, message: message, data: data}} ->
        revert_reason = Chain.format_revert_reason_message(data)

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
        %{result: %{output: outputs, names: names}, is_error: false}
    end
  end

  def prepare_read_function(function) do
    case function["outputs"] do
      {:error, text_error} ->
        function
        |> Map.put("error", text_error)
        |> Map.replace("outputs", function["abi_outputs"])
        |> Map.drop(["abi_outputs"])

      _ ->
        result =
          function
          |> Map.drop(["abi_outputs"])

        outputs = Enum.map(result["outputs"], &prepare_output/1)
        Map.replace(result, "outputs", outputs)
    end
  end

  defp prepare_output(%{"type" => type, "value" => value} = output) do
    Map.replace(output, "value", ABIEncodedValueView.value_json(type, value))
  end

  defp prepare_output(output), do: output

  # credo:disable-for-next-line
  def prepare_smart_contract(%Address{smart_contract: %SmartContract{}} = address) do
    minimal_proxy_template = Chain.get_minimal_proxy_template(address.hash, @api_true)
    twin = Chain.get_address_verified_twin_contract(address.hash, @api_true)
    metadata_for_verification = minimal_proxy_template || twin.verified_contract
    smart_contract_verified = AddressView.smart_contract_verified?(address)
    additional_sources_from_twin = twin.additional_sources
    fully_verified = Chain.smart_contract_fully_verified?(address.hash, @api_true)

    additional_sources =
      if smart_contract_verified, do: address.smart_contract_additional_sources, else: additional_sources_from_twin

    visualize_sol2uml_enabled = Sol2uml.enabled?()
    target_contract = if smart_contract_verified, do: address.smart_contract, else: metadata_for_verification

    %{
      "verified_twin_address_hash" =>
        metadata_for_verification && Address.checksum(metadata_for_verification.address_hash),
      "is_verified" => smart_contract_verified,
      "is_changed_bytecode" => smart_contract_verified && address.smart_contract.is_changed_bytecode,
      "is_partially_verified" => address.smart_contract.partially_verified && smart_contract_verified,
      "is_fully_verified" => fully_verified,
      "is_verified_via_sourcify" => address.smart_contract.verified_via_sourcify && smart_contract_verified,
      "is_vyper_contract" => target_contract.is_vyper_contract,
      "minimal_proxy_address_hash" =>
        minimal_proxy_template && Address.checksum(metadata_for_verification.address_hash),
      "sourcify_repo_url" =>
        if(address.smart_contract.verified_via_sourcify && smart_contract_verified,
          do: AddressContractView.sourcify_repo_url(address.hash, address.smart_contract.partially_verified)
        ),
      "can_be_visualized_via_sol2uml" =>
        visualize_sol2uml_enabled && !target_contract.is_vyper_contract && !is_nil(target_contract.abi),
      "name" => target_contract && target_contract.name,
      "compiler_version" => target_contract.compiler_version,
      "optimization_enabled" => if(target_contract.is_vyper_contract, do: nil, else: target_contract.optimization),
      "optimization_runs" => target_contract.optimization_runs,
      "evm_version" => target_contract.evm_version,
      "verified_at" => target_contract.inserted_at,
      "abi" => target_contract.abi,
      "source_code" => target_contract.contract_source_code,
      "file_path" => target_contract.file_path,
      "additional_sources" => Enum.map(additional_sources, &prepare_additional_source/1),
      "compiler_settings" => target_contract.compiler_settings,
      "external_libraries" => prepare_external_libraries(target_contract.external_libraries),
      "constructor_args" => if(smart_contract_verified, do: target_contract.constructor_arguments),
      "decoded_constructor_args" =>
        if(smart_contract_verified,
          do: format_constructor_arguments(target_contract.abi, target_contract.constructor_arguments)
        )
    }
    |> Map.merge(bytecode_info(address))
  end

  def prepare_smart_contract(address) do
    bytecode_info(address)
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

  def format_constructor_arguments(abi, constructor_arguments) do
    constructor_abi = Enum.find(abi, fn el -> el["type"] == "constructor" && el["inputs"] != [] end)

    input_types = Enum.map(constructor_abi["inputs"], &FunctionSelector.parse_specification_type/1)

    result =
      constructor_arguments
      |> AddressContractView.decode_data(input_types)
      |> Enum.zip(constructor_abi["inputs"])
      |> Enum.map(fn {value, %{"type" => type} = input_arg} ->
        [ABIEncodedValueView.value_json(type, value), input_arg]
      end)

    result
  rescue
    exception ->
      Logger.warn(fn ->
        [
          "Error formatting constructor arguments for abi: #{inspect(abi)}, args: #{inspect(constructor_arguments)}: ",
          Exception.format(:error, exception)
        ]
      end)

      nil
  end

  defp prepare_smart_contract_for_list(%SmartContract{} = smart_contract) do
    token =
      if smart_contract.address.token,
        do: Market.get_exchange_rate(smart_contract.address.token.symbol),
        else: Token.null()

    %{
      "address" => Helper.address_with_info(nil, smart_contract.address, smart_contract.address.hash),
      "compiler_version" => smart_contract.compiler_version,
      "optimization_enabled" => if(smart_contract.is_vyper_contract, do: nil, else: smart_contract.optimization),
      "tx_count" => smart_contract.address.transactions_count,
      "language" => smart_contract_language(smart_contract),
      "verified_at" => smart_contract.inserted_at,
      "market_cap" => token && token.market_cap_usd,
      "has_constructor_args" => !is_nil(smart_contract.constructor_arguments),
      "coin_balance" =>
        if(smart_contract.address.fetched_coin_balance, do: smart_contract.address.fetched_coin_balance.value)
    }
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
end
