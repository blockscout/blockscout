defmodule BlockScoutWeb.API.V2.ImportController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Data, Token}
  alias Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand
  alias Explorer.SmartContract.EthBytecodeDBInterface
  alias Indexer.Fetcher.TokenUpdater

  import Explorer.SmartContract.Helper, only: [prepare_bytecode_for_microservice: 3, contract_creation_input: 1]

  require Logger
  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
    Function to handle POST request to `/api/v2/import/token-info`

    Needed to import token info via admin panel.
    Protected by `x-api-key` header.
  """
  @spec import_token_info(Plug.Conn.t(), map()) ::
          {:api_key, any()}
          | {:format_address, :error}
          | {:not_found, {:error, :not_found}}
          | {:sensitive_endpoints_api_key, any()}
          | Plug.Conn.t()
  def import_token_info(
        conn,
        %{
          "icon_url" => icon_url,
          "token_address" => token_address_hash_string,
          "token_symbol" => token_symbol,
          "token_name" => token_name
        } = params
      ) do
    with {:ok, token} <- validate_api_key_address_hash_and_token(token_address_hash_string, params["api_key"]) do
      changeset =
        %{is_verified_via_admin_panel: true}
        |> put_icon_url(icon_url)
        |> put_token_string_field(token_symbol, :symbol)
        |> put_token_string_field(token_name, :name)

      case Token.update(token, changeset, true) do
        {:ok, _} ->
          conn
          |> put_view(ApiView)
          |> render(:message, %{message: "Success"})

        error ->
          Logger.warning(fn -> ["Error on importing token info: ", inspect(error)] end)

          conn
          |> put_view(ApiView)
          |> put_status(:bad_request)
          |> render(:message, %{message: "Error"})
      end
    end
  end

  # TODO: delete after successful migration from the token info service
  def import_token_info(
        conn,
        %{
          "iconUrl" => icon_url,
          "tokenAddress" => token_address_hash_string,
          "tokenSymbol" => token_symbol,
          "tokenName" => token_name
        } = params
      ) do
    with {:ok, token} <- validate_api_key_address_hash_and_token(token_address_hash_string, params["api_key"]) do
      changeset =
        %{is_verified_via_admin_panel: true}
        |> put_icon_url(icon_url)
        |> put_token_string_field(token_symbol, :symbol)
        |> put_token_string_field(token_name, :name)

      case Token.update(token, changeset, true) do
        {:ok, _} ->
          conn
          |> put_view(ApiView)
          |> render(:message, %{message: "Success"})

        error ->
          Logger.warning(fn -> ["Error on importing token info: ", inspect(error)] end)

          conn
          |> put_view(ApiView)
          |> put_status(:bad_request)
          |> render(:message, %{message: "Error"})
      end
    end
  end

  @doc """
    Function to handle request at:
      `/api/v2/import/smart-contracts/{address_hash_param}`

    Needed to try to import unverified smart contracts via eth-bytecode-db (`/api/v2/bytecodes/sources:search` method).
    Protected by `x-api-key` header.
  """
  @spec try_to_search_contract(Plug.Conn.t(), map()) ::
          {:already_verified, boolean()}
          | {:api_key, nil | binary()}
          | {:format, :error}
          | {:not_found, {:error, :not_found}}
          | {:sensitive_endpoints_api_key, any()}
          | Plug.Conn.t()
  def try_to_search_contract(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, get_api_key_header(conn)},
         {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:not_found, {:ok, address}} <-
           {:not_found,
            Chain.hash_to_address(address_hash,
              necessity_by_association: %{
                :smart_contract => :optional
              },
              api?: true
            )},
         {:nonempty_bytecode, true} <- {:nonempty_bytecode, Address.smart_contract_with_nonempty_code?(address)},
         {:already_verified, false} <-
           {:already_verified,
            not (is_nil(address.smart_contract) or
                   address.smart_contract.partially_verified)} do
      creation_transaction_input = contract_creation_input(address.hash)

      with {:ok, %{"sourceType" => type} = source} <-
             %{}
             |> prepare_bytecode_for_microservice(creation_transaction_input, Data.to_string(address.contract_code))
             |> EthBytecodeDBInterface.search_contract_in_eth_bytecode_internal_db(
               address_hash_string,
               params_to_contract_search_options(params)
             ),
           {:ok, _} <- LookUpSmartContractSourcesOnDemand.process_contract_source(type, source, address.hash) do
        conn
        |> put_view(ApiView)
        |> render(:message, %{message: "Success"})
      else
        _ ->
          conn
          |> put_view(ApiView)
          |> render(:message, %{message: "Contract was not imported"})
      end
    end
  end

  def delete_token_info(
        conn,
        %{
          "token_address_hash" => token_address_hash_string
        } = params
      ) do
    with {:ok, token} <- validate_api_key_address_hash_and_token(token_address_hash_string, params["api_key"]) do
      case Token.drop_token_info(token) do
        {:ok, _} ->
          TokenUpdater.run([token], [])

          conn
          |> put_view(ApiView)
          |> render(:message, %{message: "Success"})

        error ->
          Logger.warning(fn -> ["Error on deleting token info: ", inspect(error)] end)

          conn
          |> put_view(ApiView)
          |> put_status(:bad_request)
          |> render(:message, %{message: "Error"})
      end
    end
  end

  defp params_to_contract_search_options(%{"import_from" => "verifier_alliance"}) do
    [only_verifier_alliance?: true]
  end

  defp params_to_contract_search_options(%{"import_from" => "eth_bytecode_db"}) do
    [only_eth_bytecode_db?: true]
  end

  defp params_to_contract_search_options(_), do: []

  defp valid_url?(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.scheme != nil && uri.host =~ "."
  end

  defp valid_url?(_url), do: false

  defp put_icon_url(changeset, icon_url) do
    if valid_url?(icon_url) do
      Map.put(changeset, :icon_url, icon_url)
    else
      changeset
    end
  end

  defp put_token_string_field(changeset, token_symbol, field) when is_binary(token_symbol) do
    token_symbol = String.trim(token_symbol)

    if token_symbol !== "" do
      Map.put(changeset, field, token_symbol)
    else
      changeset
    end
  end

  defp put_token_string_field(changeset, _token_symbol, _field), do: changeset

  defp get_api_key_header(conn) do
    case get_req_header(conn, "x-api-key") do
      [api_key] ->
        api_key

      _ ->
        nil
    end
  end

  defp validate_api_key_address_hash_and_token(token_address_hash_string, provided_api_key) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, provided_api_key},
         {:format_address, {:ok, address_hash}} <-
           {:format_address, Chain.string_to_address_hash(token_address_hash_string)},
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)} do
      {:ok, token}
    end
  end
end
