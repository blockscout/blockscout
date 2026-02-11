defmodule BlockScoutWeb.API.RPC.AddressController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.API.RPC.Helper
  alias BlockScoutWeb.Chain, as: BlockScoutWebChain
  alias Explorer.{Chain, Etherscan}
  alias Explorer.Chain.{Address, PendingOperationsHelper, Wei}
  alias Explorer.Etherscan.{Addresses, Blocks}
  alias Explorer.Helper, as: ExplorerHelper
  alias Indexer.Fetcher.OnDemand.CoinBalance, as: CoinBalanceOnDemand

  @api_true [api?: true]

  @invalid_address_message "Invalid address format"
  @invalid_contract_address_message "Invalid contract address format"
  @no_internal_transactions_message "No internal transactions found"
  @no_token_transfers_message "No token transfers found"
  @results_window 10000
  @results_window_too_large_message "Result window is too large, PageNo x Offset size must be less than or equal to #{@results_window}"
  @max_safe_block_number round(:math.pow(2, 31)) - 1

  def listaccounts(conn, params) do
    case optional_params(params) do
      {:ok, options} ->
        options =
          options
          |> Map.put_new(:page_number, 0)
          |> Map.put_new(:page_size, 10)

        accounts = list_accounts(options, AccessHelper.conn_to_ip_string(conn))

        conn
        |> put_status(200)
        |> render(:listaccounts, %{accounts: accounts})

      {:error, :results_window_too_large} ->
        render(conn, :error, error: @results_window_too_large_message, data: nil)
    end
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
      addresses = hashes_to_addresses(address_hashes, AccessHelper.conn_to_ip_string(conn))
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
    with {:params, {:ok, options}} <- {:params, optional_params(params)},
         {:address_param, {:ok, address_param}} <- fetch_address(params),
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
        |> render(:error, error: @invalid_address_message)

      {:error, :not_found} ->
        render(conn, :error, error: "No transactions found", data: [])

      {:params, {:error, :results_window_too_large}} ->
        render(conn, :error, error: @results_window_too_large_message, data: nil)
    end
  end

  def txlist(conn, params) do
    with {:params, {:ok, options}} <- {:params, optional_params(params)},
         {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:address, :ok} <- {:address, Address.check_address_exists(address_hash, @api_true)},
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
        |> render(:error, error: @invalid_address_message)

      {_, :not_found} ->
        render(conn, :error, error: "No transactions found", data: [])

      {:params, {:error, :results_window_too_large}} ->
        render(conn, :error, error: @results_window_too_large_message, data: nil)
    end
  end

  def txlistinternal(conn, params) do
    case {Map.fetch(params, "txhash"), Map.fetch(params, "address")} do
      {:error, :error} ->
        txlistinternal(conn, params, :no_param)

      {_, {:ok, address_param}} ->
        txlistinternal(conn, params, address_param, :address)

      {{:ok, transaction_param}, _} ->
        txlistinternal(conn, params, transaction_param, :transaction)
    end
  end

  def txlistinternal(conn, params, transaction_param, :transaction) do
    with {:params, {:ok, options}} <- {:params, optional_params(params)},
         {:format, {:ok, transaction_hash}} <- to_transaction_hash(transaction_param),
         {:ok, transaction} <- Chain.hash_to_transaction(transaction_hash),
         {:pending, false} <- {:pending, PendingOperationsHelper.block_pending?(transaction.block_hash)},
         {:ok, internal_transactions} <- list_internal_transactions(transaction_hash, options) do
      render(conn, :txlistinternal, %{internal_transactions: internal_transactions})
    else
      {:format, :error} ->
        render(conn, :error, error: "Invalid txhash format")

      {:error, :not_found} ->
        render(conn, :error, error: @no_internal_transactions_message, data: [])

      {:params, {:error, :results_window_too_large}} ->
        render(conn, :error, error: @results_window_too_large_message, data: nil)

      {:pending, true} ->
        render(conn, :pending_internal_transaction,
          message: "Internal transactions for this transaction have not been processed yet",
          data: []
        )
    end
  end

  @block_range_not_yet_processed_message "Some internal transactions within this block range have not yet been processed"

  def txlistinternal(conn, params, address_param, :address) do
    with {:params, {:ok, options}} <- {:params, optional_params(params)},
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:address, :ok} <- {:address, Address.check_address_exists(address_hash, @api_true)},
         {{:ok, internal_transactions}, _, _} <-
           {list_internal_transactions(address_hash, options), options[:startblock], options[:endblock]} do
      render_internal_transactions(conn, internal_transactions, options[:startblock], options[:endblock])
    else
      {:format, :error} ->
        render(conn, :error, error: @invalid_address_message)

      {_, :not_found} ->
        render(conn, :error, error: @no_internal_transactions_message, data: [])

      {:params, {:error, :results_window_too_large}} ->
        render(conn, :error, error: @results_window_too_large_message, data: nil)

      {{:error, :not_found}, start_block_number, end_block_number} ->
        render_internal_transactions(conn, [], start_block_number, end_block_number)
    end
  end

  def txlistinternal(conn, params, :no_param) do
    with {:ok, options} <- optional_params(params),
         {{:ok, internal_transactions}, _, _} <-
           {list_internal_transactions(:all, options), options[:startblock], options[:endblock]} do
      render_internal_transactions(conn, internal_transactions, options[:startblock], options[:endblock])
    else
      {:error, :results_window_too_large} ->
        render(conn, :error, error: @results_window_too_large_message, data: nil)

      {{:error, :not_found}, start_block_number, end_block_number} ->
        render_internal_transactions(conn, [], start_block_number, end_block_number)
    end
  end

  defp render_internal_transactions(conn, [], start_block_number, end_block_number) do
    if PendingOperationsHelper.blocks_pending?(start_block_number, end_block_number) do
      render(conn, :pending_internal_transaction,
        message: @block_range_not_yet_processed_message,
        data: []
      )
    else
      render(conn, :error, error: @no_internal_transactions_message, data: [])
    end
  end

  defp render_internal_transactions(conn, internal_transactions, start_block_number, end_block_number) do
    if PendingOperationsHelper.blocks_pending?(start_block_number, end_block_number) do
      render(conn, :pending_internal_transaction,
        message: @block_range_not_yet_processed_message,
        data: internal_transactions
      )
    else
      render(conn, :txlistinternal, %{internal_transactions: internal_transactions})
    end
  end

  def tokentx(conn, params) do
    do_tokentx(conn, params, :erc20)
  end

  def tokennfttx(conn, params) do
    do_tokentx(conn, params, :erc721)
  end

  def token1155tx(conn, params) do
    do_tokentx(conn, params, :erc1155)
  end

  def token404tx(conn, params) do
    do_tokentx(conn, params, :erc404)
  end

  def token7984tx(conn, params) do
    do_tokentx(conn, params, :erc7984)
  end

  defp do_tokentx(conn, params, transfers_type) do
    with {:params, {:ok, options}} <- {:params, optional_params(params)},
         {:address, {:ok, address_hash}} <- {:address, to_address_hash_optional(params["address"])},
         {:contract_address, {:ok, contract_address_hash}} <-
           {:contract_address, to_address_hash_optional(params["contractaddress"])},
         true <- !is_nil(address_hash) or !is_nil(contract_address_hash),
         {:ok, token_transfers, max_block_number} <-
           list_token_transfers(transfers_type, address_hash, contract_address_hash, options) do
      render(conn, :tokentx, %{token_transfers: token_transfers, max_block_number: max_block_number})
    else
      false ->
        render(conn, :error, error: "Query parameter address or contractaddress is required")

      {:address, :error} ->
        render(conn, :error, error: @invalid_address_message)

      {:contract_address, :error} ->
        render(conn, :error, error: @invalid_contract_address_message)

      {_, :not_found} ->
        render(conn, :error, error: @no_token_transfers_message, data: [])

      {:params, {:error, :results_window_too_large}} ->
        render(conn, :error, error: @results_window_too_large_message, data: nil)
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
         {:address, :ok} <- {:address, Address.check_address_exists(address_hash, @api_true)},
         {:ok, token_list} <- list_tokens(address_hash) do
      render(conn, :token_list, %{token_list: token_list})
    else
      {:address_param, :error} ->
        render(conn, :error, error: "Query parameter address is required")

      {:format, :error} ->
        render(conn, :error, error: @invalid_address_message)

      {_, :not_found} ->
        render(conn, :error, error: "No tokens found", data: [])
    end
  end

  def getminedblocks(conn, params) do
    options = Helper.put_pagination_options(%{}, params)

    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:address, :ok} <- {:address, Address.check_address_exists(address_hash, @api_true)},
         {:ok, blocks} <- list_blocks(address_hash, options) do
      render(conn, :getminedblocks, %{blocks: blocks})
    else
      {:address_param, :error} ->
        render(conn, :error, error: "Query parameter 'address' is required")

      {:format, :error} ->
        render(conn, :error, error: @invalid_address_message)

      {_, :not_found} ->
        render(conn, :error, error: "No blocks found", data: [])
    end
  end

  @doc false
  @spec optional_params(map()) :: {:ok, map()} | {:error, :results_window_too_large}
  def optional_params(params) do
    %{}
    |> put_boolean(params, "include_zero_value", :include_zero_value)
    |> put_order_by_direction(params)
    |> Helper.put_pagination_options(params)
    |> put_block(params, "startblock")
    |> put_block(params, "endblock")
    |> put_filter_by(params)
    |> put_timestamp(params, "start_timestamp")
    |> put_timestamp(params, "end_timestamp")
    |> case do
      %{page_number: page_number, page_size: page_size} when page_number * page_size > @results_window ->
        {:error, :results_window_too_large}

      params ->
        {:ok, params}
    end
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

  defp list_accounts(%{page_number: page_number, page_size: page_size}, ip) do
    offset = (max(page_number, 1) - 1) * page_size

    # limit is just page_size
    offset
    |> Addresses.list_ordered_addresses(page_size)
    |> trigger_balances_and_add_status(ip)
  end

  defp hashes_to_addresses(address_hashes, ip) do
    address_hashes
    |> Chain.hashes_to_addresses()
    |> add_not_found_addresses(address_hashes)
    |> trigger_balances_and_add_status(ip)
  end

  defp add_not_found_addresses(addresses, hashes) do
    found_hashes = MapSet.new(addresses, & &1.hash)

    hashes
    |> MapSet.new()
    |> MapSet.difference(found_hashes)
    |> Enum.map(fn hash -> %Address{hash: hash, fetched_coin_balance: %Wei{value: 0}} end)
    |> Enum.concat(addresses)
  end

  defp trigger_balances_and_add_status(addresses, ip) do
    Enum.map(addresses, fn address ->
      case CoinBalanceOnDemand.trigger_fetch(ip, address) do
        :current ->
          %{address | stale?: false}

        _ ->
          %{address | stale?: true}
      end
    end)
  end

  defp to_address_hash_optional(nil), do: {:ok, nil}

  defp to_address_hash_optional(address_hash_string), do: Chain.string_to_address_hash(address_hash_string)

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
    {:format, Chain.string_to_full_hash(transaction_hash_string)}
  end

  defp put_boolean(options, params, params_key, options_key) do
    case params |> Map.get(params_key, "") |> String.downcase() do
      "true" -> Map.put(options, options_key, true)
      "false" -> Map.put(options, options_key, false)
      _ -> options
    end
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
         {:ok, block_number} <-
           ExplorerHelper.safe_parse_non_negative_integer(
             block_param,
             @max_safe_block_number
           ) do
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

  defp list_internal_transactions(transaction_or_address_hash_param_or_no_param, options) do
    case BlockScoutWebChain.list_internal_transactions(transaction_or_address_hash_param_or_no_param, options) do
      [] -> {:error, :not_found}
      internal_transactions -> {:ok, internal_transactions}
    end
  end

  defp list_token_transfers(transfers_type, address_hash, contract_address_hash, options) do
    with {:ok, max_block_number} <- Chain.max_consensus_block_number(),
         [_ | _] = token_transfers <-
           Etherscan.list_token_transfers(
             transfers_type,
             address_hash,
             contract_address_hash,
             options
           ) do
      {:ok, token_transfers, max_block_number}
    else
      _ -> {:error, :not_found}
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
