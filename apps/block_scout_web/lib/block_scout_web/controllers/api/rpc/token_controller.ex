defmodule BlockScoutWeb.API.RPC.TokenController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.RPC.Helpers
  alias Explorer.{Chain, Etherscan, PagingOptions}

  @default_page_size 50

  def gettoken(conn, params) do
    with {:contractaddress_param, {:ok, contractaddress_param}} <- fetch_contractaddress(params),
         {:format, {:ok, address_hash}} <- {:format, to_address_hash(contractaddress_param)},
         {:token, {:ok, token}} <- {:token, Chain.token_from_address_hash(address_hash)} do
      render(conn, "gettoken.json", %{token: token})
    else
      {:contractaddress_param, :error} ->
        render(conn, :error, error: "Query parameter contract address is required")

      {:format, {:error, "address"}} ->
        render(conn, :error, error: "Invalid contract address hash")

      {:token, {:error, :not_found}} ->
        render(conn, :error, error: "contract address not found")
    end
  end

  def tokentx(conn, params) do
    with {:required_params, {:ok, fetched_params}} <- fetch_required_params(params),
         {:format, {:ok, validated_params}} <- to_valid_format(fetched_params),
         {:token, {:ok, _}} <- {:token, Chain.token_from_address_hash(validated_params.address_hash)},
         params = validated_params |> Map.put_new(:limit, 1_000),
         {:ok, token_transfers} <- list_token_transfers(params) do
      render(conn, :tokentx, %{token_transfers: token_transfers})
    else
      {:required_params, {:error, missing_params}} ->
        error = "Required query parameters missing: #{Enum.join(missing_params, ", ")}"
        render(conn, :error, error: error)

      {:format, {:error, param}} ->
        render(conn, :error, error: "Invalid #{param} format")

      {:token, {:error, :not_found}} ->
        render(conn, :error, error: "contractaddress not found")

      {:error, :not_found} ->
        render(conn, :error, error: "No transfers found", data: [])
    end
  end

  @required_params %{
    # all_of: all of these parameters are required
    all_of: ["fromBlock", "toBlock", "contractaddress"]
  }

  @doc """
  Fetches required params. Returns error tuple if required params are missing.

  """
  @spec fetch_required_params(map()) :: {:required_params, {:ok, map()} | {:error, [String.t(), ...]}}
  def fetch_required_params(params) do
    fetched_params = Map.take(params, @required_params.all_of)

    if all_of_required_keys_found?(fetched_params) do
      {:required_params, {:ok, fetched_params}}
    else
      missing_params = get_missing_required_params(fetched_params)
      {:required_params, {:error, missing_params}}
    end
  end

  @doc """
  Prepares params for processing. Returns error tuple if invalid format is
  found.

  """
  @spec to_valid_format(map()) :: {:format, {:ok, map()} | {:error, String.t()}}
  def to_valid_format(params) do
    result =
      with {:ok, from_block} <- to_block_number(params, "fromBlock"),
           {:ok, to_block} <- to_block_number(params, "toBlock"),
           {:ok, address_hash} <- to_address_hash(params["contractaddress"]) do
        validated_params = %{
          from_block: from_block,
          to_block: to_block,
          address_hash: address_hash
        }

        {:ok, validated_params}
      else
        {:error, param_key} ->
          {:error, param_key}
      end

    {:format, result}
  end

  defp get_missing_required_params(fetched_params) do
    fetched_keys = fetched_params |> Map.keys() |> MapSet.new()

    @required_params.all_of
    |> MapSet.new()
    |> MapSet.difference(fetched_keys)
    |> MapSet.to_list()
  end

  defp all_of_required_keys_found?(fetched_params) do
    Enum.all?(@required_params.all_of, &Map.has_key?(fetched_params, &1))
  end

  defp to_block_number(params, param_key) do
    case params[param_key] do
      "latest" ->
        Chain.max_consensus_block_number()

      _ ->
        to_integer(params, param_key)
    end
  end

  defp to_integer(params, param_key) do
    case Integer.parse(params[param_key]) do
      {integer, ""} ->
        {:ok, integer}

      _ ->
        {:error, param_key}
    end
  end

  def gettokenholders(conn, params) do
    with pagination_options <- Helpers.put_pagination_options(%{}, params),
         {:contractaddress_param, {:ok, contractaddress_param}} <- fetch_contractaddress(params),
         {:format, {:ok, address_hash}} <- {:format, to_address_hash(contractaddress_param)} do
      options_with_defaults =
        pagination_options
        |> Map.put_new(:page_number, 0)
        |> Map.put_new(:page_size, 10)

      options = [
        paging_options: %PagingOptions{
          key: nil,
          page_number: options_with_defaults.page_number,
          page_size: options_with_defaults.page_size
        }
      ]

      token_holders = Chain.fetch_token_holders_from_token_hash(address_hash, options)
      render(conn, "gettokenholders.json", %{token_holders: token_holders})
    else
      {:contractaddress_param, :error} ->
        render(conn, :error, error: "Query parameter contract address is required")

      {:format, {:error, "address"}} ->
        render(conn, :error, error: "Invalid contract address hash")
    end
  end

  def bridgedtokenlist(conn, params) do
    chainid = params |> Map.get("chainid")
    destination = translate_chain_id_to_destination(chainid)

    params_with_paging_options = Helpers.put_pagination_options(%{}, params)

    page_number =
      if Map.has_key?(params_with_paging_options, :page_number), do: params_with_paging_options.page_number, else: 1

    page_size =
      if Map.has_key?(params_with_paging_options, :page_size),
        do: params_with_paging_options.page_size,
        else: @default_page_size

    options = [
      paging_options: %PagingOptions{
        key: nil,
        page_number: page_number,
        page_size: page_size
      }
    ]

    bridged_tokens = Chain.list_top_bridged_tokens(destination, nil, options)
    render(conn, "bridgedtokenlist.json", %{bridged_tokens: bridged_tokens})
  end

  defp fetch_contractaddress(params) do
    {:contractaddress_param, Map.fetch(params, "contractaddress")}
  end

  defp translate_chain_id_to_destination(destination) do
    case destination do
      "1" -> :eth
      "42" -> :kovan
      "56" -> :bsc
      "99" -> :poa
      wrong_chain_id -> wrong_chain_id
    end
  end

  defp to_address_hash(address_hash_string) do
    case Chain.string_to_address_hash(address_hash_string) do
      :error ->
        {:error, "address"}

      {:ok, address_hash} ->
        {:ok, address_hash}
    end
  end

  defp list_token_transfers(params) do
    case Etherscan.list_token_transfers(params) do
      [] -> {:error, :not_found}
      token_transfers -> {:ok, token_transfers}
    end
  end
end
