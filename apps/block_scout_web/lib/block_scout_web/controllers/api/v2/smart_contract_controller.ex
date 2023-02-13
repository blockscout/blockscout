defmodule BlockScoutWeb.API.V2.SmartContractController do
  use BlockScoutWeb, :controller

  import Explorer.SmartContract.Solidity.Verifier, only: [parse_boolean: 1]

  alias BlockScoutWeb.{AccessHelpers, AddressView}
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.{Reader, Writer}
  alias Explorer.SmartContract.Solidity.PublishHelper

  @smart_contract_address_options [
    necessity_by_association: %{
      :contracts_creation_internal_transaction => :optional,
      :smart_contract => :optional,
      :contracts_creation_transaction => :optional
    }
  ]

  @burn_address "0x0000000000000000000000000000000000000000"

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def smart_contract(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         _ <- PublishHelper.check_and_verify(address_hash_string),
         {:not_found, {:ok, address}} <-
           {:not_found, Chain.find_contract_address(address_hash, @smart_contract_address_options, true)} do
      conn
      |> put_status(200)
      |> render(:smart_contract, %{address: address})
    end
  end

  def methods_read(conn, %{"address_hash" => address_hash_string, "is_custom_abi" => "true"} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         custom_abi <- AddressView.fetch_custom_abi(conn, address_hash_string),
         {:not_found, true} <- {:not_found, AddressView.check_custom_abi_for_having_read_functions(custom_abi)} do
      read_only_functions_from_abi =
        Reader.read_only_functions_from_abi_with_sender(custom_abi.abi, address_hash, params["from"])

      read_functions_required_wallet_from_abi = Reader.read_functions_required_wallet_from_abi(custom_abi.abi)

      conn
      |> put_status(200)
      |> render(:read_functions, %{functions: read_only_functions_from_abi ++ read_functions_required_wallet_from_abi})
    end
  end

  def methods_read(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         smart_contract <- Chain.address_hash_to_smart_contract(address_hash),
         {:not_found, false} <- {:not_found, is_nil(smart_contract)} do
      read_only_functions_from_abi = Reader.read_only_functions(address_hash, params["from"])

      read_functions_required_wallet_from_abi = Reader.read_functions_required_wallet(address_hash)

      conn
      |> put_status(200)
      |> render(:read_functions, %{functions: read_only_functions_from_abi ++ read_functions_required_wallet_from_abi})
    end
  end

  def methods_write(conn, %{"address_hash" => address_hash_string, "is_custom_abi" => "true"} = params) do
    with {:format, {:ok, _address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         custom_abi <- AddressView.fetch_custom_abi(conn, address_hash_string),
         {:not_found, true} <- {:not_found, AddressView.check_custom_abi_for_having_write_functions(custom_abi)} do
      conn
      |> put_status(200)
      |> json(Writer.filter_write_functions(custom_abi.abi))
    end
  end

  def methods_write(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         smart_contract <- Chain.address_hash_to_smart_contract(address_hash),
         {:not_found, false} <- {:not_found, is_nil(smart_contract)} do
      conn
      |> put_status(200)
      |> json(Writer.write_functions(address_hash))
    end
  end

  def methods_read_proxy(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, address}} <-
           {:not_found, Chain.find_contract_address(address_hash, @smart_contract_address_options)},
         {:not_found, false} <- {:not_found, is_nil(address.smart_contract)} do
      implementation_address_hash_string =
        address.smart_contract
        |> SmartContract.get_implementation_address_hash()
        |> Tuple.to_list()
        |> List.first() || @burn_address

      conn
      |> put_status(200)
      |> render(:read_functions, %{
        functions: Reader.read_only_functions_proxy(address_hash, implementation_address_hash_string)
      })
    end
  end

  def methods_write_proxy(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, address}} <-
           {:not_found, Chain.find_contract_address(address_hash, @smart_contract_address_options)},
         {:not_found, false} <- {:not_found, is_nil(address.smart_contract)} do
      implementation_address_hash_string =
        address.smart_contract
        |> SmartContract.get_implementation_address_hash()
        |> Tuple.to_list()
        |> List.first() || @burn_address

      conn
      |> put_status(200)
      |> json(Writer.write_functions_proxy(implementation_address_hash_string))
    end
  end

  def query_read_method(
        conn,
        %{"address_hash" => address_hash_string, "contract_type" => type, "args" => args} = params
      ) do
    custom_abi =
      if parse_boolean(params["is_custom_abi"]), do: AddressView.fetch_custom_abi(conn, address_hash_string), else: nil

    contract_type = if type == "proxy", do: :proxy, else: :regular

    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, address}} <-
           {:not_found,
            Chain.find_contract_address(address_hash,
              necessity_by_association: %{
                :smart_contract => :optional
              }
            )},
         {:not_found, true} <-
           {:not_found,
            !is_nil(custom_abi) || (address.smart_contract && !match?(%NotLoaded{}, address.smart_contract))} do
      %{output: output, names: names} =
        if custom_abi do
          Reader.query_function_with_names_custom_abi(
            address_hash,
            %{method_id: params["method_id"], args: prepare_args(args)},
            params["from"],
            custom_abi.abi
          )
        else
          Reader.query_function_with_names(
            address_hash,
            %{method_id: params["method_id"], args: prepare_args(args)},
            contract_type,
            params["from"]
          )
        end

      conn
      |> put_status(200)
      |> render(:function_response, %{output: output, names: names, contract_address_hash: address_hash})
    end
  end

  def prepare_args(list) when is_list(list), do: list
  def prepare_args(other), do: [other]
end
