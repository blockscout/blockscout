defmodule BlockScoutWeb.API.V2.SmartContractController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import BlockScoutWeb.PagingHelper,
    only: [current_filter: 1, delete_parameters_from_next_page_params: 1, search_query: 1, smart_contracts_sorting: 1]

  import Explorer.SmartContract.Solidity.Verifier, only: [parse_boolean: 1]

  alias BlockScoutWeb.{AccessHelper, AddressView, CaptchaHelper}
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.Chain.SmartContract.AuditReport
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.SmartContract.Helper, as: SmartContractHelper
  alias Explorer.SmartContract.{Reader, Writer}
  alias Explorer.SmartContract.Solidity.PublishHelper
  alias Explorer.ThirdPartyIntegrations.SolidityScan

  @smart_contract_address_options [
    necessity_by_association: %{
      :contracts_creation_internal_transaction => :optional,
      [smart_contract: :smart_contract_additional_sources] => :optional,
      :contracts_creation_transaction => :optional
    },
    api?: true
  ]

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def smart_contract(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         _ <- PublishHelper.sourcify_check(address_hash_string),
         {:not_found, {:ok, address}} <-
           {:not_found, Chain.find_contract_address(address_hash, @smart_contract_address_options, false)} do
      implementations = SmartContractHelper.pre_fetch_implementations(address)

      conn
      |> put_status(200)
      |> render(:smart_contract, %{address: %Address{address | proxy_implementations: implementations}})
    end
  end

  def methods_read(conn, %{"address_hash" => address_hash_string, "is_custom_abi" => "true"} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         custom_abi <- AddressView.fetch_custom_abi(conn, address_hash_string),
         {:not_found, true} <- {:not_found, AddressView.check_custom_abi_for_having_read_functions(custom_abi)} do
      read_only_functions_from_abi =
        Reader.read_only_functions_from_abi_with_sender(custom_abi.abi, address_hash, params["from"], @api_true)

      read_functions_required_wallet_from_abi = Reader.read_functions_required_wallet_from_abi(custom_abi.abi)

      conn
      |> put_status(200)
      |> render(:read_functions, %{functions: read_only_functions_from_abi ++ read_functions_required_wallet_from_abi})
    end
  end

  def methods_read(conn, %{"address_hash" => address_hash_string} = params) do
    with {:ok, address_hash, smart_contract} <- validate_smart_contract(params, address_hash_string) do
      read_only_functions_from_abi = Reader.read_only_functions(smart_contract, address_hash, params["from"], @api_true)

      read_functions_required_wallet_from_abi = Reader.read_functions_required_wallet(smart_contract)

      conn
      |> put_status(200)
      |> render(:read_functions, %{functions: read_only_functions_from_abi ++ read_functions_required_wallet_from_abi})
    end
  end

  def methods_write(conn, %{"address_hash" => address_hash_string, "is_custom_abi" => "true"} = params) do
    with {:contract_interaction_disabled, false} <-
           {:contract_interaction_disabled, AddressView.contract_interaction_disabled?()},
         {:format, {:ok, _address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         custom_abi <- AddressView.fetch_custom_abi(conn, address_hash_string),
         {:not_found, true} <- {:not_found, AddressView.check_custom_abi_for_having_write_functions(custom_abi)} do
      conn
      |> put_status(200)
      |> json(custom_abi.abi |> Writer.filter_write_functions() |> Reader.get_abi_with_method_id())
    end
  end

  def methods_write(conn, %{"address_hash" => address_hash_string} = params) do
    with {:contract_interaction_disabled, false} <-
           {:contract_interaction_disabled, AddressView.contract_interaction_disabled?()},
         {:ok, _address_hash, smart_contract} <- validate_smart_contract(params, address_hash_string) do
      conn
      |> put_status(200)
      |> json(smart_contract |> Writer.write_functions() |> Reader.get_abi_with_method_id())
    end
  end

  def methods_read_proxy(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, address}} <-
           {:not_found, Chain.find_contract_address(address_hash, @smart_contract_address_options)},
         {:not_found, false} <- {:not_found, is_nil(address.smart_contract)} do
      implementation_address_hash_strings = get_implementations_address_hashes(address)

      functions =
        implementation_address_hash_strings
        |> Enum.reduce([], fn implementation_address_hash_string, acc ->
          functions_from_implementation =
            Reader.read_only_functions_proxy(address_hash, implementation_address_hash_string, nil, @api_true)

          acc ++ functions_from_implementation
        end)

      conn
      |> put_status(200)
      |> render(:read_functions, %{
        functions: functions
      })
    end
  end

  def methods_write_proxy(conn, %{"address_hash" => address_hash_string} = params) do
    with {:contract_interaction_disabled, false} <-
           {:contract_interaction_disabled, AddressView.contract_interaction_disabled?()},
         {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, address}} <-
           {:not_found, Chain.find_contract_address(address_hash, @smart_contract_address_options)},
         {:not_found, false} <- {:not_found, is_nil(address.smart_contract)} do
      implementation_address_hash_strings = get_implementations_address_hashes(address)

      functions =
        implementation_address_hash_strings
        |> Enum.reduce([], fn implementation_address_hash_string, acc ->
          functions_from_implementation =
            implementation_address_hash_string
            |> Writer.write_functions_proxy(@api_true)

          acc ++ functions_from_implementation
        end)

      conn
      |> put_status(200)
      |> json(
        functions
        |> Reader.get_abi_with_method_id()
      )
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
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, address}} <-
           {:not_found,
            Chain.find_contract_address(address_hash,
              necessity_by_association: %{
                :smart_contract => :optional
              },
              api?: true
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
            custom_abi.abi,
            @api_true
          )
        else
          Reader.query_function_with_names(
            address_hash,
            %{method_id: params["method_id"], args: prepare_args(args)},
            contract_type,
            params["from"],
            address.smart_contract.abi,
            true,
            @api_true
          )
        end

      conn
      |> put_status(200)
      |> render(:function_response, %{output: output, names: names, contract_address_hash: address_hash})
    end
  end

  @doc """
  /api/v2/smart-contracts/:address_hash_string/solidityscan-report logic
  """
  @spec solidityscan_report(Plug.Conn.t(), map()) ::
          {:address, {:error, :not_found}}
          | {:format_address, :error}
          | {:is_empty_response, true}
          | {:is_smart_contract, false | nil}
          | {:restricted_access, true}
          | {:is_verified_smart_contract, false}
          | {:is_vyper_contract, true}
          | Plug.Conn.t()
  def solidityscan_report(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format_address, {:ok, address_hash}} <- {:format_address, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:address, {:ok, address}} <- {:address, Chain.hash_to_address(address_hash)},
         {:is_smart_contract, true} <- {:is_smart_contract, Address.smart_contract?(address)},
         smart_contract = SmartContract.address_hash_to_smart_contract(address_hash, @api_true),
         {:is_verified_smart_contract, true} <- {:is_verified_smart_contract, !is_nil(smart_contract)},
         {:is_vyper_contract, false} <- {:is_vyper_contract, smart_contract.is_vyper_contract},
         response = SolidityScan.solidityscan_request(address_hash_string),
         {:is_empty_response, false} <- {:is_empty_response, is_nil(response)} do
      conn
      |> put_status(200)
      |> json(response)
    end
  end

  def smart_contracts_list(conn, params) do
    full_options =
      [
        necessity_by_association: %{
          [address: [:token, :names, :proxy_implementations]] => :optional,
          address: :required
        }
      ]
      |> Keyword.merge(paging_options(params))
      |> Keyword.merge(current_filter(params))
      |> Keyword.merge(search_query(params))
      |> Keyword.merge(smart_contracts_sorting(params))
      |> Keyword.merge(@api_true)

    smart_contracts_plus_one = SmartContract.verified_contracts(full_options)
    {smart_contracts, next_page} = split_list_by_page(smart_contracts_plus_one)

    next_page_params =
      next_page
      |> next_page_params(smart_contracts, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:smart_contracts, %{smart_contracts: smart_contracts, next_page_params: next_page_params})
  end

  @doc """
    POST /api/v2/smart-contracts/{address_hash}/audit-reports
  """
  @spec audit_report_submission(Plug.Conn.t(), map()) ::
          {:error, Ecto.Changeset.t()}
          | {:format, :error}
          | {:not_found, nil | Explorer.Chain.SmartContract.t()}
          | {:recaptcha, any()}
          | {:restricted_access, true}
          | Plug.Conn.t()
  def audit_report_submission(conn, %{"address_hash" => address_hash_string} = params) do
    with {:disabled, true} <- {:disabled, Application.get_env(:explorer, :air_table_audit_reports)[:enabled]},
         {:ok, address_hash, _smart_contract} <- validate_smart_contract(params, address_hash_string),
         {:recaptcha, _} <- {:recaptcha, CaptchaHelper.recaptcha_passed?(params)},
         audit_report_params <- %{
           address_hash: address_hash,
           submitter_name: params["submitter_name"],
           submitter_email: params["submitter_email"],
           is_project_owner: params["is_project_owner"],
           project_name: params["project_name"],
           project_url: params["project_url"],
           audit_company_name: params["audit_company_name"],
           audit_report_url: params["audit_report_url"],
           audit_publish_date: params["audit_publish_date"],
           comment: params["comment"]
         },
         {:ok, _} <- AuditReport.create(audit_report_params) do
      conn
      |> put_status(200)
      |> json(%{message: "OK"})
    end
  end

  @doc """
    GET /api/v2/smart-contracts/{address_hash}/audit-reports
  """
  @spec audit_reports_list(Plug.Conn.t(), map()) ::
          {:format, :error}
          | {:not_found, nil | Explorer.Chain.SmartContract.t()}
          | {:restricted_access, true}
          | Plug.Conn.t()
  def audit_reports_list(conn, %{"address_hash" => address_hash_string} = params) do
    with {:ok, address_hash, _smart_contract} <- validate_smart_contract(params, address_hash_string) do
      reports = AuditReport.get_audit_reports_by_smart_contract_address_hash(address_hash, @api_true)

      conn
      |> render(:audit_reports, %{reports: reports})
    end
  end

  def smart_contracts_counters(conn, _params) do
    conn
    |> json(%{
      smart_contracts: Chain.count_contracts_from_cache(@api_true),
      new_smart_contracts_24h: Chain.count_new_contracts_from_cache(@api_true),
      verified_smart_contracts: Chain.count_verified_contracts_from_cache(@api_true),
      new_verified_smart_contracts_24h: Chain.count_new_verified_contracts_from_cache(@api_true)
    })
  end

  def prepare_args(list) when is_list(list), do: list
  def prepare_args(other), do: [other]

  defp validate_smart_contract(params, address_hash_string) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {smart_contract, _}} when not is_nil(smart_contract) <-
           {:not_found, SmartContract.address_hash_to_smart_contract_with_bytecode_twin(address_hash, @api_true)} do
      {:ok, address_hash, smart_contract}
    end
  end

  defp get_implementations_address_hashes(proxy_address) do
    implementation =
      proxy_address.smart_contract
      |> Implementation.get_implementation(@api_true)

    (implementation && implementation.address_hashes) || []
  end
end
