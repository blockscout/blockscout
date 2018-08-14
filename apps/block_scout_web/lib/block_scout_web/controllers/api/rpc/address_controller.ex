defmodule BlockScoutWeb.API.RPC.AddressController do
  use BlockScoutWeb, :controller

  alias Explorer.{Etherscan, Chain}
  alias Explorer.Chain.{Address, Wei}

  def balance(conn, params, template \\ :balance) do
    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hashes}} <- to_address_hashes(address_param) do
      addresses = hashes_to_addresses(address_hashes)
      render(conn, template, %{addresses: addresses})
    else
      {:address_param, :error} ->
        conn
        |> put_status(200)
        |> render(:error, error: "Query parameter 'address' is required")

      {:format, :error} ->
        conn
        |> put_status(200)
        |> render(:error, error: "Invalid address hash")
    end
  end

  def balancemulti(conn, params) do
    balance(conn, params, :balancemulti)
  end

  def txlist(conn, params) do
    options = optional_params(params)

    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:ok, transactions} <- list_transactions(address_hash, options) do
      render(conn, :txlist, %{transactions: transactions})
    else
      {:address_param, :error} ->
        conn
        |> put_status(200)
        |> render(:error, error: "Query parameter 'address' is required")

      {:format, :error} ->
        conn
        |> put_status(200)
        |> render(:error, error: "Invalid address format")

      {:error, :not_found} ->
        render(conn, :error, error: "No transactions found", data: [])
    end
  end

  defp fetch_address(params) do
    {:address_param, Map.fetch(params, "address")}
  end

  defp to_address_hashes(address_param) when is_binary(address_param) do
    address_param
    |> String.split(",")
    |> Enum.take(20)
    |> to_address_hashes()
  end

  defp to_address_hashes(address_param) when is_list(address_param) do
    address_hashes = address_param_to_address_hashes(address_param)

    if any_errors?(address_hashes) do
      {:format, :error}
    else
      {:format, {:ok, address_hashes}}
    end
  end

  defp address_param_to_address_hashes(address_param) do
    Enum.map(address_param, fn single_address ->
      case Chain.string_to_address_hash(single_address) do
        {:ok, address_hash} -> address_hash
        :error -> :error
      end
    end)
  end

  defp any_errors?(address_hashes) do
    Enum.any?(address_hashes, &(&1 == :error))
  end

  defp hashes_to_addresses(address_hashes) do
    address_hashes
    |> Chain.hashes_to_addresses()
    |> add_not_found_addresses(address_hashes)
  end

  defp add_not_found_addresses(addresses, hashes) do
    found_hashes = MapSet.new(addresses, & &1.hash)

    hashes
    |> MapSet.new()
    |> MapSet.difference(found_hashes)
    |> hashes_to_addresses(:not_found)
    |> Enum.concat(addresses)
  end

  defp hashes_to_addresses(hashes, :not_found) do
    Enum.map(hashes, fn hash ->
      %Address{
        hash: hash,
        fetched_balance: %Wei{value: 0}
      }
    end)
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end

  defp optional_params(params) do
    %{}
    |> put_order_by_direction(params)
    |> put_pagination_options(params)
    |> put_start_block(params)
    |> put_end_block(params)
  end

  defp put_order_by_direction(options, params) do
    case params do
      %{"sort" => sort} when sort in ["asc", "desc"] ->
        order_by_direction = String.to_existing_atom(sort)
        Map.put(options, :order_by_direction, order_by_direction)

      _ ->
        options
    end
  end

  defp put_pagination_options(options, params) do
    with %{"page" => page, "offset" => offset} <- params,
         {page_number, ""} when page_number > 0 <- Integer.parse(page),
         {page_size, ""} when page_size > 0 <- Integer.parse(offset),
         :ok <- validate_max_page_size(page_size) do
      options
      |> Map.put(:page_number, page_number)
      |> Map.put(:page_size, page_size)
    else
      _ ->
        options
    end
  end

  defp validate_max_page_size(page_size) do
    if page_size <= Etherscan.page_size_max(), do: :ok, else: :error
  end

  defp put_start_block(options, params) do
    with %{"startblock" => startblock_param} <- params,
         {start_block, ""} <- Integer.parse(startblock_param) do
      Map.put(options, :start_block, start_block)
    else
      _ ->
        options
    end
  end

  defp put_end_block(options, params) do
    with %{"endblock" => endblock_param} <- params,
         {end_block, ""} <- Integer.parse(endblock_param) do
      Map.put(options, :end_block, end_block)
    else
      _ ->
        options
    end
  end

  defp list_transactions(address_hash, options) do
    case Etherscan.list_transactions(address_hash, options) do
      [] -> {:error, :not_found}
      transactions -> {:ok, transactions}
    end
  end
end
