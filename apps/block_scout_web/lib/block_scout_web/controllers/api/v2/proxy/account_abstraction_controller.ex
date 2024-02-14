defmodule BlockScoutWeb.API.V2.Proxy.AccountAbstractionController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.V2.Helper

  alias Explorer.Chain
  alias Explorer.MicroserviceInterfaces.AccountAbstraction

  @address_fields ["bundler", "entry_point", "sender", "address", "factory", "paymaster"]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/operations/:user_operation_hash_param` endpoint.
  """
  @spec operation(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def operation(conn, %{"operation_hash_param" => operation_hash_string}) do
    operation_hash_string
    |> AccountAbstraction.get_user_ops_by_hash()
    |> process_response(conn)
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/bundlers/:address_hash_param` endpoint.
  """
  @spec bundler(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def bundler(conn, %{"address_hash_param" => address_hash_string}) do
    address_hash_string
    |> AccountAbstraction.get_bundler_by_hash()
    |> process_response(conn)
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/bundlers` endpoint.
  """
  @spec bundlers(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def bundlers(conn, query_string) do
    query_string
    |> AccountAbstraction.get_bundlers()
    |> process_response(conn)
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/factories/:address_hash_param` endpoint.
  """
  @spec factory(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def factory(conn, %{"address_hash_param" => address_hash_string}) do
    address_hash_string
    |> AccountAbstraction.get_factory_by_hash()
    |> process_response(conn)
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/factories` endpoint.
  """
  @spec factories(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def factories(conn, query_string) do
    query_string
    |> AccountAbstraction.get_factories()
    |> process_response(conn)
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/paymasters/:address_hash_param` endpoint.
  """
  @spec paymaster(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def paymaster(conn, %{"address_hash_param" => address_hash_string}) do
    address_hash_string
    |> AccountAbstraction.get_paymaster_by_hash()
    |> process_response(conn)
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/paymasters` endpoint.
  """
  @spec paymasters(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def paymasters(conn, query_string) do
    query_string
    |> AccountAbstraction.get_paymasters()
    |> process_response(conn)
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/accounts/:address_hash_param` endpoint.
  """
  @spec account(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def account(conn, %{"address_hash_param" => address_hash_string}) do
    address_hash_string
    |> AccountAbstraction.get_account_by_hash()
    |> process_response(conn)
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/accounts` endpoint.
  """
  @spec accounts(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def accounts(conn, query_string) do
    query_string
    |> AccountAbstraction.get_accounts()
    |> process_response(conn)
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/bundles` endpoint.
  """
  @spec bundles(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def bundles(conn, query_string) do
    query_string
    |> AccountAbstraction.get_bundles()
    |> process_response(conn)
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/account-abstraction/operations` endpoint.
  """
  @spec operations(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def operations(conn, query_string) do
    query_string
    |> AccountAbstraction.get_operations()
    |> process_response(conn)
  end

  defp extended_info(response) do
    case response do
      %{"items" => items} ->
        extended_items =
          Enum.map(items, fn response_item ->
            add_address_extended_info(response_item)
          end)

        response
        |> Map.put("items", extended_items)

      _ ->
        add_address_extended_info(response)
    end
  end

  defp add_address_extended_info(response) do
    @address_fields
    |> Enum.reduce(response, fn address_output_field, output_response ->
      if Map.has_key?(output_response, address_output_field) do
        output_response
        |> Map.replace(
          address_output_field,
          address_info_from_hash_string(Map.get(output_response, address_output_field))
        )
      else
        output_response
      end
    end)
  end

  defp address_info_from_hash_string(address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <-
           Chain.hash_to_address(
             address_hash,
             [
               necessity_by_association: %{
                 :names => :optional,
                 :smart_contract => :optional
               }
             ],
             false
           ) do
      Helper.address_with_info(address, address_hash_string)
    else
      _ -> address_hash_string
    end
  end

  defp process_response(response, conn) do
    case response do
      {:error, :disabled} ->
        conn
        |> put_status(501)
        |> json(extended_info(%{message: "Service is disabled"}))

      {status_code, response} ->
        conn
        |> put_status(status_code)
        |> json(extended_info(response))
    end
  end
end
