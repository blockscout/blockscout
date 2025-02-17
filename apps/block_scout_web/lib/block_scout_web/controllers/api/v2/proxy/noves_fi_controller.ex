defmodule BlockScoutWeb.API.V2.Proxy.NovesFiController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.RPC.ContractController
  alias BlockScoutWeb.API.V2.TransactionController
  alias Explorer.ThirdPartyIntegrations.NovesFi

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
    Function to handle GET requests to `/api/v2/proxy/noves-fi/transactions/:transaction_hash_param` endpoint.
  """
  @spec transaction(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def transaction(conn, %{"transaction_hash_param" => transaction_hash_string} = params) do
    with {:ok, _transaction, _transaction_hash} <-
           TransactionController.validate_transaction(transaction_hash_string, params,
             necessity_by_association: %{},
             api?: true
           ),
         url = NovesFi.transaction_url(transaction_hash_string),
         {response, status} <- NovesFi.api_request(url, conn),
         {:is_empty_response, false} <- {:is_empty_response, is_nil(response)} do
      conn
      |> put_status(status)
      |> json(response)
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/noves-fi/addresses/:address_hash_param/transactions` endpoint.
  """
  @spec address_transactions(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def address_transactions(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, _address_hash, _address} <- ContractController.validate_address(address_hash_string, params),
         url = NovesFi.address_transactions_url(address_hash_string),
         {response, status} <- NovesFi.api_request(url, conn),
         {:is_empty_response, false} <- {:is_empty_response, is_nil(response)} do
      conn
      |> put_status(status)
      |> json(response)
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/proxy/noves-fi/transaction-descriptions` endpoint.
  """
  @spec describe_transactions(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def describe_transactions(conn, _) do
    url = NovesFi.describe_transactions_url()

    with {response, status} <- NovesFi.api_request(url, conn, :post_transactions),
         {:is_empty_response, false} <- {:is_empty_response, is_nil(response)} do
      conn
      |> put_status(status)
      |> json(response)
    end
  end
end
