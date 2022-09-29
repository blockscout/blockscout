defmodule BlockScoutWeb.API.RPC.AddressController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.RPC.Helpers
  alias Explorer.{Chain, Etherscan}
  alias Explorer.Chain.{Address, Wei}
  alias Explorer.Etherscan.{Addresses, Blocks}
  alias Indexer.Fetcher.CoinBalanceOnDemand

  def listaccounts(conn, params) do
    options =
      params
      |> optional_params()
      |> Map.put_new(:page_number, 0)
      |> Map.put_new(:page_size, 10)

    accounts = list_accounts(options)

    conn
    |> put_status(200)
    |> render(:listaccounts, %{accounts: accounts})
  end

  def eth_get_balance(conn, params) do
    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:block_param, {:ok, block}} <- {:block_param, fetch_block_param(params)},
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:balance, {:ok, balance}} <- {:balance, Blocks.get_balance_as_of_block(address_hash, block)} do
      render(conn, :eth_get_balance, %{balance: Wei.hex_format(balance)})
    else
      {:address_param, :error} ->
        conn
        |> put_status(400)
        |> render(:eth_get_balance_error, %{message: "Query parameter 'address' is required"})

      {:format, :error} ->
        conn
        |> put_status(400)
        |> render(:eth_get_balance_error, %{error: "Invalid address hash"})

      {:block_param, :error} ->
        conn
        |> put_status(400)
        |> render(:eth_get_balance_error, %{error: "Invalid block"})

      {:balance, {:error, :not_found}} ->
        conn
        |> put_status(404)
        |> render(:eth_get_balance_error, %{error: "Balance not found"})
    end
  end

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

  def pendingtxlist(conn, params) do
    options = optional_params(params)

    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:ok, transactions} <- list_pending_transactions(address_hash, options) do
      render(conn, :pendingtxlist, %{transactions: transactions})
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

  def txlist(conn, params) do
    options = optional_params(params)

    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:address, :ok} <- {:address, Chain.check_address_exists(address_hash)},
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

      {_, :not_found} ->
        render(conn, :error, error: "No transactions found", data: [])
    end
  end

  def txlistinternal(conn, params) do
    case {Map.fetch(params, "txhash"), Map.fetch(params, "address")} do
      {:error, :error} ->
        render(conn, :error, error: "Query parameter txhash or address is required")

      {{:ok, txhash_param}, :error} ->
        txlistinternal(conn, txhash_param, :txhash)

      {:error, {:ok, address_param}} ->
        txlistinternal(conn, params, address_param, :address)
    end
  end

  def txlistinternal(conn, txhash_param, :txhash) do
    with {:format, {:ok, transaction_hash}} <- to_transaction_hash(txhash_param),
         {:ok, internal_transactions} <- list_internal_transactions(transaction_hash) do
      render(conn, :txlistinternal, %{internal_transactions: internal_transactions})
    else
      {:format, :error} ->
        render(conn, :error, error: "Invalid txhash format")

      {:error, :not_found} ->
        render(conn, :error, error: "No internal transactions found", data: [])
    end
  end

  def txlistinternal(conn, params, address_param, :address) do
    options = optional_params(params)

    with {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:address, :ok} <- {:address, Chain.check_address_exists(address_hash)},
         {:ok, internal_transactions} <- list_internal_transactions(address_hash, options) do
      render(conn, :txlistinternal, %{internal_transactions: internal_transactions})
    else
      {:format, :error} ->
        render(conn, :error, error: "Invalid address format")

      {_, :not_found} ->
        render(conn, :error, error: "No internal transactions found", data: [])
    end
  end

  def tokentx(conn, params) do
    options = optional_params(params)

    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:contract_address, {:ok, contract_address_hash}} <- to_contract_address_hash(params["contractaddress"]),
         {:address, :ok} <- {:address, Chain.check_address_exists(address_hash)},
         {:ok, token_transfers} <- list_token_transfers(address_hash, contract_address_hash, options) do
      render(conn, :tokentx, %{token_transfers: token_transfers})
    else
      {:address_param, :error} ->
        render(conn, :error, error: "Query parameter address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid address format")

      {:contract_address, :error} ->
        render(conn, :error, error: "Invalid contract address format")

      {_, :not_found} ->
        render(conn, :error, error: "No token transfers found", data: [])
    end
  end

  @tokenbalance_required_params ~w(contractaddress address)

  def tokenbalance(conn, params) do
    with {:required_params, {:ok, fetched_params}} <- fetch_required_params(params, @tokenbalance_required_params),
         {:format, {:ok, validated_params}} <- to_valid_format(fetched_params, :tokenbalance) do
      token_balance = get_token_balance(validated_params)
      render(conn, "tokenbalance.json", %{token_balance: token_balance})
    else
      {:required_params, {:error, missing_params}} ->
        error = "Required query parameters missing: #{Enum.join(missing_params, ", ")}"
        render(conn, :error, error: error)

      {:format, {:error, param}} ->
        render(conn, :error, error: "Invalid #{param} format")
    end
  end

  def tokenlist(conn, params) do
    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:address, :ok} <- {:address, Chain.check_address_exists(address_hash)},
         {:ok, token_list} <- list_tokens(address_hash) do
      render(conn, :token_list, %{token_list: token_list})
    else
      {:address_param, :error} ->
        render(conn, :error, error: "Query parameter address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid address format")

      {_, :not_found} ->
        render(conn, :error, error: "No tokens found", data: [])
    end
  end

  def getminedblocks(conn, params) do
    options = Helpers.put_pagination_options(%{}, params)

    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:address, :ok} <- {:address, Chain.check_address_exists(address_hash)},
         {:ok, blocks} <- list_blocks(address_hash, options) do
      render(conn, :getminedblocks, %{blocks: blocks})
    else
      {:address_param, :error} ->
        render(conn, :error, error: "Query parameter 'address' is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid address format")

      {_, :not_found} ->
        render(conn, :error, error: "No blocks found", data: [])
    end
  end

  @doc """
  Sanitizes optional params.

  """
  @spec optional_params(map()) :: map()
  def optional_params(params) do
    %{}
    |> put_order_by_direction(params)
    |> Helpers.put_pagination_options(params)
    |> put_block(params, "start_block")
    |> put_block(params, "end_block")
    |> put_filter_by(params)
    |> put_timestamp(params, "start_timestamp")
    |> put_timestamp(params, "end_timestamp")
  end

  @doc """
  Fetches required params. Returns error tuple if required params are missing.

  """
  @spec fetch_required_params(map(), list()) :: {:required_params, {:ok, map()} | {:error, [String.t(), ...]}}
  def fetch_required_params(params, required_params) do
    fetched_params = Map.take(params, required_params)

    result =
      if all_of_required_keys_found?(fetched_params, required_params) do
        {:ok, fetched_params}
      else
        missing_params = get_missing_required_params(fetched_params, required_params)
        {:error, missing_params}
      end

    {:required_params, result}
  end

  defp fetch_block_param(%{"block" => "latest"}), do: {:ok, :latest}
  defp fetch_block_param(%{"block" => "earliest"}), do: {:ok, :earliest}
  defp fetch_block_param(%{"block" => "pending"}), do: {:ok, :pending}

  defp fetch_block_param(%{"block" => string_integer}) when is_bitstring(string_integer) do
    case Integer.parse(string_integer) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  defp fetch_block_param(%{"block" => _block}), do: :error
  defp fetch_block_param(_), do: {:ok, :latest}

  defp to_valid_format(params, :tokenbalance) do
    result =
      with {:ok, contract_address_hash} <- to_address_hash(params, "contractaddress"),
           {:ok, address_hash} <- to_address_hash(params, "address") do
        {:ok, %{contract_address_hash: contract_address_hash, address_hash: address_hash}}
      else
        {:error, _param_key} = error -> error
      end

    {:format, result}
  end

  defp all_of_required_keys_found?(fetched_params, required_params) do
    Enum.all?(required_params, &Map.has_key?(fetched_params, &1))
  end

  defp get_missing_required_params(fetched_params, required_params) do
    fetched_keys = fetched_params |> Map.keys() |> MapSet.new()

    required_params
    |> MapSet.new()
    |> MapSet.difference(fetched_keys)
    |> MapSet.to_list()
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

  defp list_accounts(%{page_number: page_number, page_size: page_size}) do
    offset = (max(page_number, 1) - 1) * page_size

    # limit is just page_size
    offset
    |> Addresses.list_ordered_addresses(page_size)
    |> trigger_balances_and_add_status()
  end

  defp hashes_to_addresses(address_hashes) do
    address_hashes
    |> Chain.hashes_to_addresses()
    |> trigger_balances_and_add_status()
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
        fetched_coin_balance: %Wei{value: 0}
      }
    end)
  end

  defp trigger_balances_and_add_status(addresses) do
    Enum.map(addresses, fn address ->
      case CoinBalanceOnDemand.trigger_fetch(address) do
        :current ->
          %{address | stale?: false}

        _ ->
          %{address | stale?: true}
      end
    end)
  end

  defp to_contract_address_hash(nil), do: {:contract_address, {:ok, nil}}

  defp to_contract_address_hash(address_hash_string) do
    {:contract_address, Chain.string_to_address_hash(address_hash_string)}
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end

  defp to_address_hash(params, param_key) do
    case Chain.string_to_address_hash(params[param_key]) do
      {:ok, address_hash} -> {:ok, address_hash}
      :error -> {:error, param_key}
    end
  end

  defp to_transaction_hash(transaction_hash_string) do
    {:format, Chain.string_to_transaction_hash(transaction_hash_string)}
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

  # sobelow_skip ["DOS.StringToAtom"]
  defp put_block(options, params, key) do
    with %{^key => block_param} <- params,
         {block_number, ""} <- Integer.parse(block_param) do
      Map.put(options, String.to_atom(key), block_number)
    else
      _ ->
        options
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp put_filter_by(options, params) do
    case params do
      %{"filter_by" => filter_by} when filter_by in ["from", "to"] ->
        Map.put(options, String.to_atom("filter_by"), filter_by)

      _ ->
        options
    end
  end

  def put_timestamp({:ok, options}, params, timestamp_param_key) do
    options = put_timestamp(options, params, timestamp_param_key)
    {:ok, options}
  end

  # sobelow_skip ["DOS.StringToAtom"]
  def put_timestamp(options, params, timestamp_param_key) do
    with %{^timestamp_param_key => timestamp_param} <- params,
         {unix_timestamp, ""} <- Integer.parse(timestamp_param),
         {:ok, timestamp} <- DateTime.from_unix(unix_timestamp) do
      Map.put(options, String.to_atom(timestamp_param_key), timestamp)
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

  defp list_pending_transactions(address_hash, options) do
    case Etherscan.list_pending_transactions(address_hash, options) do
      [] -> {:error, :not_found}
      pending_transactions -> {:ok, pending_transactions}
    end
  end

  defp list_internal_transactions(transaction_hash) do
    case Etherscan.list_internal_transactions(transaction_hash) do
      [] -> {:error, :not_found}
      internal_transactions -> {:ok, internal_transactions}
    end
  end

  defp list_internal_transactions(address_hash, options) do
    case Etherscan.list_internal_transactions(address_hash, options) do
      [] -> {:error, :not_found}
      internal_transactions -> {:ok, internal_transactions}
    end
  end

  defp list_token_transfers(address_hash, contract_address_hash, options) do
    case Etherscan.list_token_transfers(address_hash, contract_address_hash, options) do
      [] -> {:error, :not_found}
      token_transfers -> {:ok, token_transfers}
    end
  end

  defp list_blocks(address_hash, options) do
    case Etherscan.list_blocks(address_hash, options) do
      [] -> {:error, :not_found}
      blocks -> {:ok, blocks}
    end
  end

  defp get_token_balance(%{contract_address_hash: contract_address_hash, address_hash: address_hash}) do
    case Etherscan.get_token_balance(contract_address_hash, address_hash) do
      nil -> 0
      token_balance -> token_balance.value
    end
  end

  defp list_tokens(address_hash) do
    case Etherscan.list_tokens(address_hash) do
      [] -> {:error, :not_found}
      token_list -> {:ok, token_list}
    end
  end
end
