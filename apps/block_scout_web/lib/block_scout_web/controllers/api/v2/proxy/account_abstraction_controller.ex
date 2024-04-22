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
    address_hashes =
      response
      |> collect_address_hashes()
      |> Chain.hashes_to_addresses(
        necessity_by_association: %{
          :names => :optional,
          :smart_contract => :optional
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
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.uniq()
    |> Enum.map(fn hash_string ->
      case Chain.string_to_address_hash(hash_string) do
        {:ok, hash} -> hash
        _ -> nil
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
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
        |> json(extended_info(%{message: "Service is disabled"}))

      {status_code, response} ->
        conn
        |> put_status(status_code)
        |> json(extended_info(response))
    end
  end
end
