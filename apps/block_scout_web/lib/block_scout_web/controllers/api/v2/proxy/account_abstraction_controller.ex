defmodule BlockScoutWeb.API.V2.Proxy.AccountAbstractionController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias BlockScoutWeb.API.V2.Helper
  alias BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation, as: TransactionInterpretationService
  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.{BadRequestResponse, NotFoundResponse, NotImplementedResponse}
  alias Explorer.Chain
  alias Explorer.MicroserviceInterfaces.AccountAbstraction

  @address_fields ["bundler", "entry_point", "sender", "address", "factory", "paymaster", "execute_target"]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  tags(["account_abstraction"])

  operation :operation,
    summary: "Get a user operation by hash",
    description: "Retrieves a user operation by its hash.",
    parameters: [operation_hash_param() | base_params()],
    responses: [
      ok: {"User operation", "application/json", Schemas.Proxy.AccountAbstraction.UserOperation},
      not_found: NotFoundResponse.response(),
      bad_request: BadRequestResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/operations/:user_operation_hash_param` endpoint.
  """
  @spec operation(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def operation(conn, %{"operation_hash_param" => operation_hash_string}) do
    operation_hash_string
    |> AccountAbstraction.get_user_ops_by_hash()
    |> process_response(conn)
  end

  operation :summary,
    summary: "Get a human-readable, LLM-based user operation summary",
    description: "Retrieves a human-readable summary of what a user operation did, presented in natural language.",
    parameters: base_params() ++ [operation_hash_param(), just_request_body_param()],
    responses: [
      ok:
        {"Human-readable summary of the specified user operation.", "application/json",
         %Schema{
           anyOf: [
             Schemas.Transaction.Summary,
             Schemas.Transaction.SummaryJustRequestBody
           ]
         }},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/operations/:user_operation_hash_param/summary` endpoint.
  """
  @spec summary(Plug.Conn.t(), map()) ::
          {:error | :format | :transaction_interpreter_enabled | non_neg_integer(), any()} | Plug.Conn.t()
  def summary(conn, %{"operation_hash_param" => operation_hash_string, "just_request_body" => "true"}) do
    with {:format, {:ok, _operation_hash}} <- {:format, Chain.string_to_full_hash(operation_hash_string)},
         {:transaction_interpreter_enabled, true} <-
           {:transaction_interpreter_enabled, TransactionInterpretationService.enabled?()},
         {200, %{"hash" => _} = user_op} <- AccountAbstraction.get_user_ops_by_hash(operation_hash_string) do
      conn
      |> json(TransactionInterpretationService.get_user_op_request_body(user_op))
    end
  end

  def summary(conn, %{"operation_hash_param" => operation_hash_string}) do
    with {:format, {:ok, _operation_hash}} <- {:format, Chain.string_to_full_hash(operation_hash_string)},
         {:transaction_interpreter_enabled, true} <-
           {:transaction_interpreter_enabled, TransactionInterpretationService.enabled?()},
         {200, %{"hash" => _} = user_op} <- AccountAbstraction.get_user_ops_by_hash(operation_hash_string) do
      {response, code} =
        case TransactionInterpretationService.interpret_user_operation(user_op) do
          {:ok, response} -> {response, 200}
          {:error, %Jason.DecodeError{}} -> {%{error: "Error while transaction interpreter response decoding"}, 500}
          {{:error, error}, code} -> {%{error: error}, code}
        end

      conn
      |> put_status(code)
      |> json(response)
    end
  end

  operation :bundler,
    summary: "Get a bundler by address hash",
    description: "Retrieves a bundler by its address hash.",
    parameters: [address_hash_param() | base_params()],
    responses: [
      ok: {"Bundler", "application/json", Schemas.Proxy.AccountAbstraction.Bundler},
      not_found: NotFoundResponse.response(),
      bad_request: BadRequestResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/bundlers/:address_hash_param` endpoint.
  """
  @spec bundler(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def bundler(conn, %{"address_hash_param" => address_hash_string}) do
    address_hash_string
    |> AccountAbstraction.get_bundler_by_hash()
    |> process_response(conn)
  end

  operation :bundlers,
    summary: "List of top bundlers",
    description: "Retrieves a list of top bundlers.",
    parameters: base_params() ++ define_paging_params(["page_size", "page_token"]),
    responses: [
      ok:
        {"List of bundlers with pagination.", "application/json",
         paginated_response(
           items: Schemas.Proxy.AccountAbstraction.Bundler,
           next_page_params_example: %{
             "page_size" => 50,
             "page_token" => "5,0x9B67A24A474e9EC7372c23B023f36ab28831e4C4"
           }
         )},
      bad_request: BadRequestResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/bundlers` endpoint.
  """
  @spec bundlers(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def bundlers(conn, query_string) do
    query_string
    |> AccountAbstraction.get_bundlers()
    |> process_response(conn)
  end

  operation :factory,
    summary: "Get a factory by address hash",
    description: "Retrieves a factory by its address hash.",
    parameters: [address_hash_param() | base_params()],
    responses: [
      ok: {"Factory", "application/json", Schemas.Proxy.AccountAbstraction.Factory},
      not_found: NotFoundResponse.response(),
      bad_request: BadRequestResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/factories/:address_hash_param` endpoint.
  """
  @spec factory(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def factory(conn, %{"address_hash_param" => address_hash_string}) do
    address_hash_string
    |> AccountAbstraction.get_factory_by_hash()
    |> process_response(conn)
  end

  operation :factories,
    summary: "List of top wallet factories",
    description: "Retrieves a list of top wallet factories.",
    parameters: base_params() ++ define_paging_params(["page_size", "page_token"]),
    responses: [
      ok:
        {"List of factories with pagination.", "application/json",
         paginated_response(
           items: Schemas.Proxy.AccountAbstraction.Factory,
           next_page_params_example: %{
             "page_size" => 50,
             "page_token" => "3,0xC23957e7Fea98eBD017abe15a4e7770797ff6D8d"
           }
         )},
      bad_request: BadRequestResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/factories` endpoint.
  """
  @spec factories(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def factories(conn, query_string) do
    query_string
    |> AccountAbstraction.get_factories()
    |> process_response(conn)
  end

  operation :paymaster,
    summary: "Get a paymaster by address hash",
    description: "Retrieves a paymaster by its address hash.",
    parameters: [address_hash_param() | base_params()],
    responses: [
      ok: {"Paymaster", "application/json", Schemas.Proxy.AccountAbstraction.Paymaster},
      not_found: NotFoundResponse.response(),
      bad_request: BadRequestResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/paymasters/:address_hash_param` endpoint.
  """
  @spec paymaster(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def paymaster(conn, %{"address_hash_param" => address_hash_string}) do
    address_hash_string
    |> AccountAbstraction.get_paymaster_by_hash()
    |> process_response(conn)
  end

  operation :paymasters,
    summary: "List of top paymasters",
    description: "Retrieves a list of top paymasters.",
    parameters: base_params() ++ define_paging_params(["page_size", "page_token"]),
    responses: [
      ok:
        {"List of paymasters with pagination.", "application/json",
         paginated_response(
           items: Schemas.Proxy.AccountAbstraction.Paymaster,
           next_page_params_example: %{
             "page_size" => 50,
             "page_token" => "19,0xB98Cb1dA4F9BD640879F0bBCb30A541c84163406"
           }
         )},
      bad_request: BadRequestResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/paymasters` endpoint.
  """
  @spec paymasters(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def paymasters(conn, query_string) do
    query_string
    |> AccountAbstraction.get_paymasters()
    |> process_response(conn)
  end

  operation :account,
    summary: "Get an account abstraction wallet by address hash",
    description: "Retrieves an account abstraction wallet by its address hash.",
    parameters: [address_hash_param() | base_params()],
    responses: [
      ok: {"Account", "application/json", Schemas.Proxy.AccountAbstraction.Account},
      not_found: NotFoundResponse.response(),
      bad_request: BadRequestResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/accounts/:address_hash_param` endpoint.
  """
  @spec account(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def account(conn, %{"address_hash_param" => address_hash_string}) do
    address_hash_string
    |> AccountAbstraction.get_account_by_hash()
    |> process_response(conn)
  end

  operation :accounts,
    summary: "List of account abstraction wallets",
    description: "Retrieves a list of account abstraction wallets.",
    parameters: base_params() ++ define_paging_params(["page_size", "page_token"]),
    responses: [
      ok:
        {"List of account abstraction wallets with pagination.", "application/json",
         paginated_response(
           items: Schemas.Proxy.AccountAbstraction.Account,
           next_page_params_example: %{
             "page_size" => 50,
             "page_token" => "0x29cB129476609bBa26372b23427Af3b87cB23aF6"
           }
         )},
      bad_request: BadRequestResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/accounts` endpoint.
  """
  @spec accounts(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def accounts(conn, query_string) do
    query_string
    |> AccountAbstraction.get_accounts()
    |> process_response(conn)
  end

  operation :bundles,
    summary: "List of recent bundles",
    description: "Retrieves a list of recent bundles.",
    parameters: base_params() ++ define_paging_params(["page_size", "page_token"]),
    responses: [
      ok:
        {"List of bundles with pagination.", "application/json",
         paginated_response(
           items: Schemas.Proxy.AccountAbstraction.Bundle,
           next_page_params_example: %{
             "page_size" => 50,
             "page_token" => "3949699,0x275f7110df7d73e530f3381daa9d422dea80f036b514e56427d2d7e492c8a81f,0"
           }
         )},
      bad_request: BadRequestResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/bundles` endpoint.
  """
  @spec bundles(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def bundles(conn, query_string) do
    query_string
    |> AccountAbstraction.get_bundles()
    |> process_response(conn)
  end

  operation :operations,
    summary: "List of recent user operations",
    description: "Retrieves a list of recent user operations.",
    parameters: base_params() ++ define_paging_params(["page_size", "page_token"]),
    responses: [
      ok:
        {"List of user operations with pagination.", "application/json",
         paginated_response(
           items: Schemas.Proxy.AccountAbstraction.UserOperationInList,
           next_page_params_example: %{
             "page_size" => 50,
             "page_token" => "3937439,0xbb680271614883525ac8056c388489e80b3518ec12ec46e1b910c7238c46b565"
           }
         )},
      bad_request: BadRequestResponse.response(),
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/operations` endpoint.
  """
  @spec operations(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def operations(conn, query_string) do
    query_string
    |> AccountAbstraction.get_operations()
    |> process_response(conn)
  end

  operation :status,
    summary: "Get the status of the account abstraction microservice",
    description: "Retrieves the status of the account abstraction microservice.",
    parameters: base_params(),
    responses: [
      ok: {"Status", "application/json", Schemas.Proxy.AccountAbstraction.Status},
      not_implemented: NotImplementedResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/status` endpoint.
  """
  @spec status(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def status(conn, params) do
    params
    |> AccountAbstraction.get_status()
    |> process_response(conn)
  end

  defp extended_info(response) do
    address_hashes =
      response
      |> collect_address_hashes()
      |> Chain.hashes_to_addresses(
        necessity_by_association: %{
          :names => :optional,
          :smart_contract => :optional,
          proxy_implementations_association() => :optional
        },
        api?: true
      )
      |> Enum.into(%{}, &{&1.hash, Helper.address_with_info(&1, nil)})

    response |> replace_address_hashes(address_hashes)
  end

  defp collect_address_hashes(response) do
    address_hash_strings =
      case response do
        %{"items" => items} ->
          @address_fields |> Enum.flat_map(fn field -> Enum.map(items, & &1[field]) end)

        item ->
          @address_fields |> Enum.map(&item[&1])
      end

    address_hash_strings
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.map(&Chain.string_to_address_hash_or_nil/1)
    |> Enum.reject(&is_nil/1)
  end

  defp replace_address_hashes(response, addresses) do
    case response do
      %{"items" => items} ->
        extended_items = items |> Enum.map(&add_address_extended_info(&1, addresses))

        response |> Map.put("items", extended_items)

      item ->
        add_address_extended_info(item, addresses)
    end
  end

  defp add_address_extended_info(response, addresses) do
    @address_fields
    |> Enum.reduce(response, fn address_output_field, output_response ->
      with true <- Map.has_key?(output_response, address_output_field),
           {:ok, address_hash} <- output_response |> Map.get(address_output_field) |> Chain.string_to_address_hash(),
           true <- Map.has_key?(addresses, address_hash) do
        output_response |> Map.replace(address_output_field, Map.get(addresses, address_hash))
      else
        _ -> output_response
      end
    end)
  end

  defp process_response(response, conn) do
    case response do
      {:error, :disabled} ->
        conn
        |> put_status(501)
        |> json(%{message: "Service is disabled"})

      {status_code, response} ->
        final_json = response |> try_to_decode_call_data() |> extended_info()

        conn
        |> put_status(status_code)
        |> json(final_json)
    end
  end

  defp try_to_decode_call_data(%{"call_data" => _call_data} = user_op) do
    user_op_hash = user_op["hash"]

    {_mock_transaction, _decoded_call_data, decoded_call_data_json} =
      TransactionInterpretationService.decode_user_op_calldata(user_op_hash, user_op["call_data"])

    {_mock_transaction, _decoded_execute_call_data, decoded_execute_call_data_json} =
      TransactionInterpretationService.decode_user_op_calldata(user_op_hash, user_op["execute_call_data"])

    user_op
    |> Map.put("decoded_call_data", decoded_call_data_json)
    |> Map.put("decoded_execute_call_data", decoded_execute_call_data_json)
  end

  defp try_to_decode_call_data(response), do: response
end
