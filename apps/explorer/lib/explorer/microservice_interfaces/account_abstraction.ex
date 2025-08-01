defmodule Explorer.MicroserviceInterfaces.AccountAbstraction do
  @moduledoc """
    Interface to interact with Blockscout Account Abstraction (EIP-4337) microservice
  """

  alias Explorer.HttpClient
  alias Explorer.Utility.Microservice
  require Logger

  @doc """
    Get user operation by hash via GET {{baseUrl}}/api/v1/userOps/:hash
  """
  @spec get_user_ops_by_hash(binary()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_user_ops_by_hash(user_operation_hash_string) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      query_params = %{}

      http_get_request(operation_by_hash_url(user_operation_hash_string), query_params)
    end
  end

  @doc """
    Get operations list via GET {{baseUrl}}/api/v1/operations
  """
  @spec get_operations(map()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_operations(query_params) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      http_get_request(operations_url(), query_params)
    end
  end

  @doc """
    Get bundler by address hash via GET {{baseUrl}}/api/v1/bundlers/:address
  """
  @spec get_bundler_by_hash(binary()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_bundler_by_hash(address_hash_string) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      query_params = %{}

      http_get_request(bundler_by_hash_url(address_hash_string), query_params)
    end
  end

  @doc """
    Get bundlers list via GET {{baseUrl}}/api/v1/bundlers
  """
  @spec get_bundlers(map()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_bundlers(query_params) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      http_get_request(bundlers_url(), query_params)
    end
  end

  @doc """
    Get factory by address hash via GET {{baseUrl}}/api/v1/factories/:address
  """
  @spec get_factory_by_hash(binary()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_factory_by_hash(address_hash_string) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      query_params = %{}

      http_get_request(factory_by_hash_url(address_hash_string), query_params)
    end
  end

  @doc """
    Get factories list via GET {{baseUrl}}/api/v1/factories
  """
  @spec get_factories(map()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_factories(query_params) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      http_get_request(factories_url(), query_params)
    end
  end

  @doc """
    Get paymaster by address hash via GET {{baseUrl}}/api/v1/paymasters/:address
  """
  @spec get_paymaster_by_hash(binary()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_paymaster_by_hash(address_hash_string) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      query_params = %{}

      http_get_request(paymaster_by_hash_url(address_hash_string), query_params)
    end
  end

  @doc """
    Get paymasters list via GET {{baseUrl}}/api/v1/paymasters
  """
  @spec get_paymasters(map()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_paymasters(query_params) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      http_get_request(paymasters_url(), query_params)
    end
  end

  @doc """
    Get account by address hash via GET {{baseUrl}}/api/v1/accounts/:address
  """
  @spec get_account_by_hash(binary()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_account_by_hash(address_hash_string) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      query_params = %{}

      http_get_request(account_by_hash_url(address_hash_string), query_params)
    end
  end

  @doc """
    Get accounts list via GET {{baseUrl}}/api/v1/accounts
  """
  @spec get_accounts(map()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_accounts(query_params) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      http_get_request(accounts_url(), query_params)
    end
  end

  @doc """
    Get bundles list via GET {{baseUrl}}/api/v1/bundles
  """
  @spec get_bundles(map()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_bundles(query_params) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      http_get_request(bundles_url(), query_params)
    end
  end

  @doc """
    Get status via GET {{baseUrl}}/api/v1/status
  """
  @spec get_status(map()) :: {non_neg_integer(), map()} | {:error, :disabled}
  def get_status(query_params) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      http_get_request(status_url(), query_params)
    end
  end

  defp http_get_request(url, query_params) do
    case HttpClient.get(url, [], params: query_params) do
      {:ok, %{body: body, status_code: status_code}}
      when status_code in [200, 404] ->
        {:ok, response_json} = Jason.decode(body)
        {status_code, response_json}

      {_, %{body: body, status_code: status_code} = error} ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to Account Abstraction microservice url: #{url}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:ok, response_json} = Jason.decode(body)
        {status_code, response_json}

      {:error, reason} ->
        {500, %{error: reason}}
    end
  end

  @spec enabled?() :: boolean
  def enabled?, do: Application.get_env(:explorer, __MODULE__)[:enabled]

  defp operation_by_hash_url(user_op_hash) do
    "#{base_url()}/userOps/#{user_op_hash}"
  end

  defp operations_url do
    "#{base_url()}/userOps"
  end

  defp bundler_by_hash_url(address_hash) do
    "#{base_url()}/bundlers/#{address_hash}"
  end

  defp bundlers_url do
    "#{base_url()}/bundlers"
  end

  defp factory_by_hash_url(address_hash) do
    "#{base_url()}/factories/#{address_hash}"
  end

  defp factories_url do
    "#{base_url()}/factories"
  end

  defp paymaster_by_hash_url(address_hash) do
    "#{base_url()}/paymasters/#{address_hash}"
  end

  defp paymasters_url do
    "#{base_url()}/paymasters"
  end

  defp account_by_hash_url(address_hash) do
    "#{base_url()}/accounts/#{address_hash}"
  end

  defp accounts_url do
    "#{base_url()}/accounts"
  end

  defp bundles_url do
    "#{base_url()}/bundles"
  end

  defp status_url do
    "#{base_url()}/status"
  end

  defp base_url do
    "#{Microservice.base_url(__MODULE__)}/api/v1"
  end
end
