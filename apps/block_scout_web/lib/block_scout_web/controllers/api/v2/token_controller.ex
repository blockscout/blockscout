defmodule BlockScoutWeb.API.V2.TokenController do
  use BlockScoutWeb, :controller
  use Utils.CompileTimeEnvHelper, bridged_tokens_enabled: [:explorer, [Explorer.Chain.BridgedToken, :enabled]]
  use OpenApiSpex.ControllerSpecs

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.API.V2.{AddressView, TransactionView}
  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.NotFoundResponse
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{Address, BridgedToken, Token, Token.Instance}
  alias Explorer.Migrator.BackfillMetadataURL
  alias Indexer.Fetcher.OnDemand.NFTCollectionMetadataRefetch, as: NFTCollectionMetadataRefetchOnDemand
  alias Indexer.Fetcher.OnDemand.TokenInstanceMetadataRefetch, as: TokenInstanceMetadataRefetchOnDemand
  alias Indexer.Fetcher.OnDemand.TokenTotalSupply, as: TokenTotalSupplyOnDemand
  alias Plug.Conn

  import Explorer.Chain.Address.Reputation, only: [reputation_association: 0]

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      paging_options: 1,
      next_page_params: 3,
      token_transfers_next_page_params: 3,
      unique_tokens_paging_options: 1,
      unique_tokens_next_page: 3,
      fetch_scam_token_toggle: 2
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      chain_ids_filter_options: 1,
      token_transfers_types_options: 1,
      tokens_sorting: 1
    ]

  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1]
  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]
  import Explorer.PagingOptions, only: [default_paging_options: 0]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["tokens"])

  @api_true [api?: true]

  @token_options [api?: true, necessity_by_association: %{reputation_association() => :optional}]

  operation :token,
    summary: "Retrieve detailed information about a specific token",
    description: "Retrieves detailed information for a specific token identified by its contract address.",
    parameters: [address_hash_param() | base_params()],
    responses: [
      ok: {"Detailed information about the specified token.", "application/json", Schemas.Token.Response},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/tokens/:address_hash_param` endpoint.
  """
  @spec token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def token(conn, %{address_hash_param: address_hash_string} = params) do
    ip = AccessHelper.conn_to_ip_string(conn)

    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @token_options)} do
      TokenTotalSupplyOnDemand.trigger_fetch(ip, address_hash)

      conn
      |> token_response(token, address_hash)
    end
  end

  if @bridged_tokens_enabled do
    defp token_response(conn, token, address_hash) do
      if token.bridged do
        bridged_token =
          Chain.select_repo(@api_true).get_by(BridgedToken, home_token_contract_address_hash: address_hash)

        conn
        |> put_status(200)
        |> render(:bridged_token, %{token: {token, bridged_token}})
      else
        conn
        |> put_status(200)
        |> render(:token, %{token: token})
      end
    end
  else
    defp token_response(conn, token, _address_hash) do
      conn
      |> put_status(200)
      |> render(:token, %{token: token})
    end
  end

  operation :counters,
    summary: "Get holder and transfer count statistics for a specific token",
    description: "Retrieves count statistics for a specific token, including holders count and transfers count.",
    parameters: [address_hash_param() | base_params()],
    responses: [
      ok: {"Count statistics for the specified token.", "application/json", Schemas.Token.Counters},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/tokens/:address_hash_param/counters` endpoint.
  """
  @spec counters(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def counters(conn, %{address_hash_param: address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, true} <- {:not_found, Token.by_contract_address_hash_exists?(address_hash, @api_true)} do
      {transfers_count, holders_count} = Chain.fetch_token_counters(address_hash, 5_000)

      json(conn, %{transfers_count: to_string(transfers_count), token_holders_count: to_string(holders_count)})
    end
  end

  operation :transfers,
    summary: "List ownership transfer history for a specific NFT",
    description: "Retrieves transfer history for a specific NFT instance, showing ownership changes over time.",
    parameters:
      base_params() ++
        [address_hash_param()] ++
        define_paging_params([
          "index",
          "block_number",
          "batch_log_index",
          "batch_block_hash",
          "batch_transaction_hash",
          "index_in_batch"
        ]),
    responses: [
      ok:
        {"Transfers of the specified token, with pagination.", "application/json",
         paginated_response(
           items: Schemas.TokenTransfer,
           next_page_params_example: %{
             "index" => 259,
             "block_number" => 23_484_141,
             "batch_log_index" => 3,
             "batch_block_hash" => "0x789",
             "batch_transaction_hash" => "0xabc",
             "index_in_batch" => 2
           }
         )},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/tokens/:address_hash_param/transfers` endpoint.
  """
  @spec transfers(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers(conn, %{address_hash_param: address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, true} <- {:not_found, Token.by_contract_address_hash_exists?(address_hash, @api_true)} do
      paging_options = paging_options(params)

      results =
        address_hash
        |> Chain.fetch_token_transfers_from_token_hash(Keyword.merge(@api_true, paging_options))
        |> Chain.flat_1155_batch_token_transfers()
        |> Chain.paginate_1155_batch_token_transfers(paging_options)

      {token_transfers, next_page} = split_list_by_page(results)

      next_page_params =
        next_page
        |> token_transfers_next_page_params(token_transfers, params)

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:token_transfers, %{
        token_transfers:
          token_transfers |> Instance.preload_nft(@api_true) |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation :holders,
    summary: "List addresses holding a specific token sorted by balance",
    description:
      "Retrieves addresses holding a specific token, sorted by balance. Useful for analyzing token distribution.",
    parameters:
      base_params() ++
        [address_hash_param()] ++
        define_paging_params(["address_hash_param", "value", "items_count"]),
    responses: [
      ok:
        {"Holders of the specified token, with pagination.", "application/json",
         paginated_response(
           items: Schemas.Token.Holder,
           next_page_params_example: %{
             "address_hash" => "0x48bb9b14483e43c7726df702b271d410e7460656",
             "value" => "200000000000000",
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/tokens/:address_hash_param/holders` endpoint.
  """
  @spec holders(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def holders(conn, %{address_hash_param: address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, true} <- {:not_found, Token.by_contract_address_hash_exists?(address_hash, @api_true)} do
      results_plus_one =
        Chain.fetch_token_holders_from_token_hash(address_hash, Keyword.merge(paging_options(params), @api_true))

      {token_balances, next_page} = split_list_by_page(results_plus_one)

      next_page_params = next_page |> next_page_params(token_balances, params)

      conn
      |> put_status(200)
      |> render(:token_holders, %{
        token_balances: token_balances |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation :instances,
    summary: "List individual NFT instances for a token contract",
    description:
      "Retrieves instances of NFTs for a specific token contract. This endpoint is primarily for ERC-721 and ERC-1155 tokens.",
    parameters:
      base_params() ++
        [address_hash_param(), holder_address_hash_param()] ++
        define_paging_params(["unique_token"]),
    responses: [
      ok:
        {"NFT instances for the specified token contract, with pagination.", "application/json",
         paginated_response(
           items: Schemas.TokenInstance,
           next_page_params_example: %{
             "unique_token" => 782_098
           }
         )},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/tokens/:address_hash_param/instances` endpoint.
  """
  @spec instances(Plug.Conn.t(), map()) :: Plug.Conn.t()

  def instances(
        conn,
        %{address_hash_param: address_hash_string, holder_address_hash: holder_address_hash_string} = params
      ) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @token_options)},
         {:not_found, false} <- {:not_found, Chain.erc_20_token?(token) or Token.zrc_2_token?(token)},
         {:format, {:ok, holder_address_hash}} <- {:format, Chain.string_to_address_hash(holder_address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(holder_address_hash_string, params) do
      holder_address_with_proxy_implementations =
        case Address.get(holder_address_hash, @api_true) do
          %Address{} = holder_address -> %Address{holder_address | proxy_implementations: nil}
          nil -> nil
        end

      results_plus_one =
        Instance.token_instances_by_holder_address_hash(
          token,
          holder_address_hash,
          params
          |> unique_tokens_paging_options()
          |> Keyword.merge(@api_true)
        )

      {token_instances, next_page} = split_list_by_page(results_plus_one)

      next_page_params =
        next_page
        |> unique_tokens_next_page(token_instances, params)

      conn
      |> put_status(200)
      |> put_view(AddressView)
      |> render(:nft_list, %{
        token_instances:
          token_instances
          |> put_owner(holder_address_with_proxy_implementations, holder_address_hash)
          |> maybe_preload_ens()
          |> maybe_preload_metadata(),
        next_page_params: next_page_params,
        token: token
      })
    end
  end

  def instances(conn, %{address_hash_param: address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @token_options)} do
      results_plus_one =
        Instance.address_to_unique_tokens(
          token.contract_address_hash,
          token,
          Keyword.merge(unique_tokens_paging_options(params), @api_true)
        )

      {token_instances, next_page} = split_list_by_page(results_plus_one)

      next_page_params =
        next_page |> unique_tokens_next_page(token_instances, params)

      conn
      |> put_status(200)
      |> render(:token_instances, %{
        token_instances: token_instances |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params,
        token: token
      })
    end
  end

  operation :instance,
    summary: "Retrieve detailed information about a specific NFT",
    description:
      "Retrieves detailed information about a specific NFT instance, identified by its token contract address and token ID.",
    parameters:
      base_params() ++
        [
          address_hash_param(),
          token_id_param()
        ],
    responses: [
      ok: {"Detailed information about the specified NFT instance.", "application/json", Schemas.TokenInstance},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/tokens/:address_hash_param/instances/:token_id_param` endpoint.
  """
  @spec instance(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def instance(conn, %{address_hash_param: address_hash_string, token_id_param: token_id_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @token_options)},
         {:not_found, false} <- {:not_found, Chain.erc_20_token?(token) or Token.zrc_2_token?(token)},
         {:format, {token_id, ""}} <- {:format, Integer.parse(token_id_string)},
         {:ok, token_instance} <-
           Instance.nft_instance_by_token_id_and_token_address(token_id, address_hash, @api_true) do
      fill_metadata_url_task = maybe_run_fill_metadata_url_task(token_instance, token)

      %Instance{} =
        token_instance =
        token_instance
        |> Chain.select_repo(@api_true).preload(owner: [:names, :smart_contract, proxy_implementations_association()])
        |> Instance.put_owner_to_token_instance(token, @api_true)

      updated_token_instance =
        case fill_metadata_url_task && (Task.yield(fill_metadata_url_task) || Task.ignore(fill_metadata_url_task)) do
          {:ok, [%{error: error}]} when not is_nil(error) ->
            %Instance{token_instance | metadata: nil}

          _ ->
            token_instance
        end

      conn
      |> put_status(200)
      |> render(:token_instance, %{
        token_instance: updated_token_instance,
        token: token
      })
    end
  end

  operation :transfers_by_instance,
    summary: "List token transfers for a specific token instance",
    description: "Retrieves token transfers for a specific token instance (by token address and token ID).",
    parameters:
      base_params() ++
        [address_hash_param(), token_id_param()] ++
        define_paging_params(["index", "block_number", "token_id"]),
    responses: [
      ok:
        {"Transfer history for the specified NFT instance, with pagination.", "application/json",
         paginated_response(
           items: Schemas.TokenTransfer,
           next_page_params_example: %{
             "index" => 920,
             "block_number" => 23_489_243,
             "token_id" => "4"
           }
         )},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/tokens/:address_hash_param/instances/:token_id_param/transfers` endpoint.
  """
  @spec transfers_by_instance(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_by_instance(
        conn,
        %{address_hash_param: address_hash_string, token_id_param: token_id_string} = params
      ) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)},
         {:not_found, false} <- {:not_found, Chain.erc_20_token?(token) or Token.zrc_2_token?(token)},
         {:format, {token_id, ""}} <- {:format, Integer.parse(token_id_string)} do
      paging_options = paging_options(params)

      results =
        address_hash
        |> Chain.fetch_token_transfers_from_token_hash_and_token_id(token_id, Keyword.merge(paging_options, @api_true))
        |> Chain.flat_1155_batch_token_transfers(Decimal.new(token_id))
        |> Chain.paginate_1155_batch_token_transfers(paging_options)

      {token_transfers, next_page} = split_list_by_page(results)

      next_page_params =
        next_page
        |> token_transfers_next_page_params(token_transfers, params)

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:token_transfers, %{
        token_transfers: token_transfers |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation :holders_by_instance,
    summary: "List current holders of a specific NFT",
    description:
      "Retrieves current holders of a specific NFT instance. For ERC-721, this will typically be a single address. For ERC-1155, multiple addresses may hold the same token ID.",
    parameters:
      base_params() ++
        [address_hash_param(), token_id_param()] ++
        define_paging_params(["address_hash_param", "items_count", "token_id", "value"]),
    responses: [
      ok:
        {"Current holders of the specified NFT instance, with pagination.", "application/json",
         paginated_response(
           items: Schemas.Token.Holder,
           next_page_params_example: %{
             "address_hash" => "0x1d2c163fbda9486c3a384b6fa5e34c96fe948e9a",
             "items_count" => 50,
             "token_id" => "0",
             "value" => "4217417051704137590935"
           }
         )},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/tokens/:address_hash_param/instances/:token_id_param/holders` endpoint.
  """
  @spec holders_by_instance(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def holders_by_instance(conn, %{address_hash_param: address_hash_string, token_id_param: token_id_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)},
         {:not_found, false} <- {:not_found, Chain.erc_20_token?(token) or Token.zrc_2_token?(token)},
         {:format, {token_id, ""}} <- {:format, Integer.parse(token_id_string)} do
      paging_options = paging_options(params)

      results =
        Chain.fetch_token_holders_from_token_hash_and_token_id(
          address_hash,
          token_id,
          Keyword.merge(paging_options, @api_true)
        )

      {token_holders, next_page} = split_list_by_page(results)

      next_page_params =
        next_page
        |> next_page_params(token_holders, params)

      conn
      |> put_status(200)
      |> render(:token_holders, %{
        token_balances: token_holders |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation :transfers_count_by_instance,
    summary: "Get total number of ownership transfers for a specific NFT",
    description:
      "Retrieves the total number of transfers for a specific NFT instance. Useful for determining how frequently an NFT has changed hands.",
    parameters:
      base_params() ++
        [
          address_hash_param(),
          token_id_param()
        ],
    responses: [
      ok:
        {"Total number of transfers for the specified NFT instance.", "application/json",
         %Schema{type: :object, properties: %{transfers_count: %Schema{type: :integer}}}},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/tokens/:address_hash_param/instances/:token_id_param/transfers-count` endpoint.
  """
  @spec transfers_count_by_instance(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_count_by_instance(
        conn,
        %{address_hash_param: address_hash_string, token_id_param: token_id_string} = params
      ) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)},
         {:not_found, false} <- {:not_found, Chain.erc_20_token?(token) or Token.zrc_2_token?(token)},
         {:format, {token_id, ""}} <- {:format, Integer.parse(token_id_string)} do
      conn
      |> put_status(200)
      |> json(%{
        transfers_count: Chain.count_token_transfers_from_token_hash_and_token_id(address_hash, token_id, @api_true)
      })
    end
  end

  operation :tokens_list,
    summary: "List tokens with optional filtering by name, symbol, or type",
    description: "Retrieves a paginated list of tokens with optional filtering by name, symbol, or type.",
    parameters:
      base_params() ++
        [
          token_type_param(),
          q_param(),
          limit_param(),
          sort_param(["fiat_value", "holders_count", "circulating_market_cap"]),
          order_param()
        ] ++
        define_paging_params([
          "contract_address_hash",
          "fiat_value",
          "holders_count",
          "is_name_null",
          "market_cap",
          "name",
          "items_count"
        ]),
    responses: [
      ok:
        {"List of tokens matching the filter criteria, with pagination.", "application/json",
         paginated_response(
           items: Schemas.Token,
           next_page_params_example: %{
             "contract_address_hash" => "0xbe9895146f7af43049ca1c1ae358b0541ea49704",
             "fiat_value" => "4724.32",
             "holders_count" => 59_731,
             "is_name_null" => false,
             "market_cap" => "570958125.135513",
             "name" => "Wrapped Staked ETH",
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/tokens` endpoint.
  """
  @spec tokens_list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def tokens_list(conn, params) do
    filter = params[:q]

    options =
      params
      |> paging_options()
      |> Keyword.update(:paging_options, default_paging_options(), fn %PagingOptions{
                                                                        page_size: page_size
                                                                      } = paging_options ->
        maybe_parsed_limit = params[:limit]
        %PagingOptions{paging_options | page_size: min(page_size, maybe_parsed_limit && abs(maybe_parsed_limit))}
      end)
      |> Keyword.merge(token_transfers_types_options(params))
      |> Keyword.merge(tokens_sorting(params))
      |> Keyword.merge(@api_true)
      |> fetch_scam_token_toggle(conn)

    {tokens, next_page} = filter |> Token.list_top(options) |> split_list_by_page()

    next_page_params = next_page |> next_page_params(tokens, params)

    conn
    |> put_status(200)
    |> render(:tokens, %{tokens: tokens, next_page_params: next_page_params})
  end

  operation :bridged_tokens_list,
    summary: "List bridged tokens with optional filtering and sorting",
    description: "Retrieves a paginated list of bridged tokens with optional filtering and sorting.",
    parameters:
      base_params() ++
        [chain_ids_param(), q_param()] ++
        define_paging_params([
          "contract_address_hash",
          "fiat_value",
          "holders_count",
          "is_name_null",
          "market_cap",
          "name",
          "items_count"
        ]),
    responses: [
      ok:
        {"List of bridged tokens.", "application/json",
         paginated_response(
           items: Schemas.Token,
           next_page_params_example: %{
             "contract_address_hash" => "0xbe9895146f7af43049ca1c1ae358b0541ea49704",
             "fiat_value" => "4724.32",
             "holders_count" => 59_731,
             "is_name_null" => false,
             "market_cap" => "570958125.135513",
             "name" => "Wrapped Staked ETH",
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/tokens/bridged` endpoint.
  """
  @spec bridged_tokens_list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def bridged_tokens_list(conn, params) do
    filter = params[:q]

    options =
      params
      |> paging_options()
      |> Keyword.merge(chain_ids_filter_options(params))
      |> Keyword.merge(tokens_sorting(params))
      |> Keyword.merge(@api_true)

    {tokens, next_page} = filter |> BridgedToken.list_top_bridged_tokens(options) |> split_list_by_page()

    next_page_params = next_page |> next_page_params(tokens, params)

    conn
    |> put_status(200)
    |> render(:bridged_tokens, %{tokens: tokens, next_page_params: next_page_params})
  end

  operation :refetch_metadata,
    summary: "Trigger a refresh of metadata for a specific NFT",
    description:
      "Triggers a refresh of metadata for a specific NFT instance. Useful when the NFT's metadata has been updated but is not yet reflected in the BlockScout database.",
    parameters:
      base_params() ++
        [
          address_hash_param(),
          token_id_param(),
          recaptcha_response_param()
        ],
    responses: [
      ok:
        {"Metadata refresh has been successfully initiated.", "application/json",
         %Schema{type: :object, properties: %{message: %Schema{type: :string}}}},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles PATCH requests to `/api/v2/tokens/:address_hash_param/instances/:token_id_param/refetch-metadata` endpoint.
  """
  @spec refetch_metadata(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def refetch_metadata(
        conn,
        params
      ) do
    address_hash_string = params[:address_hash_param]
    token_id_string = params[:token_id_param]

    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)},
         {:not_found, false} <- {:not_found, Chain.erc_20_token?(token) or Token.zrc_2_token?(token)},
         {:format, {token_id, ""}} <- {:format, Integer.parse(token_id_string)},
         {:ok, token_instance} <-
           Instance.nft_instance_by_token_id_and_token_address(token_id, address_hash, @api_true) do
      token_instance_with_token =
        token_instance
        |> put_token_to_instance(token)

      conn
      |> AccessHelper.conn_to_ip_string()
      |> TokenInstanceMetadataRefetchOnDemand.trigger_refetch(token_instance_with_token)

      conn
      |> put_status(200)
      |> json(%{message: "OK"})
    end
  end

  operation :trigger_nft_collection_metadata_refetch,
    summary: "Trigger metadata refetch for a token's NFT collection",
    description: "Triggers a metadata refetch for a token's NFT collection (by token address). Requires API key.",
    parameters: base_params() ++ [address_hash_param(), admin_api_key_param(), admin_api_key_param_query()],
    responses: [
      ok:
        {"NFT collection metadata refetch triggered.", "application/json",
         %Schema{type: :object, properties: %{message: %Schema{type: :string}}}},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles PATCH requests to `/api/v2/tokens/:address_hash_param/instances/refetch-metadata` endpoint.
  """
  @spec trigger_nft_collection_metadata_refetch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def trigger_nft_collection_metadata_refetch(
        conn,
        params
      ) do
    address_hash_string = params[:address_hash_param]
    ip = AccessHelper.conn_to_ip_string(conn)

    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <-
           {:api_key, get_api_key(conn)},
         {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)},
         {:not_found, false} <- {:not_found, Chain.erc_20_token?(token) or Token.zrc_2_token?(token)} do
      NFTCollectionMetadataRefetchOnDemand.trigger_refetch(ip, token)

      conn
      |> put_status(200)
      |> json(%{message: "OK"})
    end
  end

  defp get_api_key(conn) do
    case Conn.get_req_header(conn, "x-api-key") do
      [api_key] ->
        api_key

      _ ->
        Map.get(conn.query_params, "api_key")
    end
  end

  defp maybe_run_fill_metadata_url_task(token_instance, token) do
    if not is_nil(token_instance.metadata) && is_nil(token_instance.skip_metadata_url) do
      Task.async(fn ->
        BackfillMetadataURL.update_batch([
          {token_instance.token_contract_address_hash, token_instance.token_id, token.type}
        ])
      end)
    else
      nil
    end
  end

  defp put_owner(token_instances, holder_address, holder_address_hash),
    do:
      Enum.map(token_instances, fn %Instance{} = token_instance ->
        %Instance{token_instance | owner: holder_address, owner_address_hash: holder_address_hash}
      end)

  @spec put_token_to_instance(Instance.t(), Token.t()) :: Instance.t()
  defp put_token_to_instance(
         %Instance{} = token_instance,
         token
       ) do
    %Instance{token_instance | token: token}
  end
end
