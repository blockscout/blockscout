defmodule BlockScoutWeb.API.V2.AddressView do
  use BlockScoutWeb, :view

  alias ABI.FunctionSelector
  alias BlockScoutWeb.{ABIEncodedValueView, AddressContractView, AddressView}
  alias BlockScoutWeb.API.V2.{ApiView, Helper, TokenView}
  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.ExchangeRates.Token

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("address.json", %{address: address, conn: conn}) do
    prepare_address(address, conn)
  end

  def render("token_balances.json", %{token_balances: token_balances}) do
    Enum.map(token_balances, &prepare_token_balance/1)
  end

  def render("coin_balance.json", %{coin_balance: coin_balance}) do
    prepare_coin_balance_history_entry(coin_balance)
  end

  def render("coin_balances.json", %{coin_balances: coin_balances, next_page_params: next_page_params}) do
    %{"items" => Enum.map(coin_balances, &prepare_coin_balance_history_entry/1), "next_page_params" => next_page_params}
  end

  def render("coin_balances_by_day.json", %{coin_balances_by_day: coin_balances_by_day}) do
    Enum.map(coin_balances_by_day, &prepare_coin_balance_history_by_day_entry/1)
  end

  def render("smart_contract.json", %{address: address}) do
    prepare_smart_contract(address)
  end

  def prepare_address(address, conn \\ nil) do
    base_info = Helper.address_with_info(conn, address, address.hash)
    is_proxy = AddressView.smart_contract_is_proxy?(address)

    {implementation_address, implementation_name} =
      with true <- is_proxy,
           {address, name} <- SmartContract.get_implementation_address_hash(address.smart_contract),
           false <- is_nil(address),
           {:ok, address_hash} <- Chain.string_to_address_hash(address),
           checksummed_address <- Address.checksum(address_hash) do
        {checksummed_address, name}
      else
        _ ->
          {nil, nil}
      end

    balance = address.fetched_coin_balance && address.fetched_coin_balance.value
    exchange_rate = (Market.get_exchange_rate(Explorer.coin()) || Token.null()).usd_value

    creator_hash = AddressView.from_address_hash(address)
    creation_tx = creator_hash && AddressView.transaction_hash(address)
    token = address.token && TokenView.render("token.json", %{token: Market.add_price(address.token)})

    Map.merge(base_info, %{
      "creator_address_hash" => creator_hash && Address.checksum(creator_hash),
      "creation_tx_hash" => creation_tx,
      "token" => token,
      "coin_balance" => balance,
      "exchange_rate" => exchange_rate,
      "implementation_name" => implementation_name,
      "implementation_address" => implementation_address,
      "block_number_balance_updated_at" => address.fetched_coin_balance_block_number,
      "has_methods_read" =>
        AddressView.smart_contract_with_read_only_functions?(address) ||
          AddressView.has_address_custom_abi_with_read_functions?(conn, address.hash),
      "has_methods_write" =>
        AddressView.smart_contract_with_write_functions?(address) ||
          AddressView.has_address_custom_abi_with_write_functions?(conn, address.hash),
      "has_methods_read_proxy" => is_proxy,
      "has_methods_write_proxy" => AddressView.smart_contract_with_write_functions?(address) && is_proxy
    })
  end

  def prepare_token_balance({token_balance, token}) do
    %{
      "value" => token_balance.value,
      "token" => TokenView.render("token.json", %{token: token}),
      "token_id" => token_balance.token_id
    }
  end

  def prepare_coin_balance_history_entry(coin_balance) do
    %{
      "transaction_hash" => coin_balance.transaction_hash,
      "block_number" => coin_balance.block_number,
      "delta" => coin_balance.delta,
      "value" => coin_balance.value,
      "block_timestamp" => coin_balance.block_timestamp
    }
  end

  def prepare_coin_balance_history_by_day_entry(coin_balance_by_day) do
    %{
      "date" => coin_balance_by_day.date,
      "value" => coin_balance_by_day.value
    }
  end

  def prepare_smart_contract(address) do
    minimal_proxy_template = Chain.get_minimal_proxy_template(address.hash)

    metadata_for_verification =
      minimal_proxy_template || Chain.get_address_verified_twin_contract(address.hash).verified_contract

    smart_contract_verified = AddressView.smart_contract_verified?(address)
    additional_sources_from_twin = Chain.get_address_verified_twin_contract(address.hash).additional_sources
    fully_verified = Chain.smart_contract_fully_verified?(address.hash)

    additional_sources =
      if smart_contract_verified, do: address.smart_contract_additional_sources, else: additional_sources_from_twin

    visualize_sol2uml_enabled = Explorer.Visualize.Sol2uml.enabled?()
    target_contract = if smart_contract_verified, do: address.smart_contract, else: metadata_for_verification

    %{
      "verified_twin_address_hash" => metadata_for_verification && metadata_for_verification.address_hash,
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
      "additional_sources" => Enum.map(additional_sources, &prepare_additional_sourse/1),
      "compiler_settings" => target_contract.compiler_settings,
      "external_libraries" => target_contract.external_libraries,
      "constructor_args" => target_contract.constructor_arguments,
      "decoded_constructor_args" =>
        format_constructor_arguments(target_contract.abi, target_contract.constructor_arguments)
    }
    |> Map.merge(bytecode_info(address))

    # |>
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

  defp prepare_additional_sourse(source) do
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
        {ABIEncodedValueView.value_json(type, value), input_arg}
      end)

    result
  rescue
    _ -> nil
  end
end
