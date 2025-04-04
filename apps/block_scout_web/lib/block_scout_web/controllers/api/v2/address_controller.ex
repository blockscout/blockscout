defmodule BlockScoutWeb.API.V2.AddressController do
  use BlockScoutWeb, :controller
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]
  use Utils.RuntimeEnvHelper, chain_type: [:explorer, :chain_type]

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      next_page_params: 4,
      token_transfers_next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1,
      current_filter: 1,
      paging_params_with_fiat_value: 1,
      fetch_scam_token_toggle: 2
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      addresses_sorting: 1,
      delete_parameters_from_next_page_params: 1,
      token_transfers_types_options: 1,
      address_transactions_sorting: 1,
      nft_types_options: 1
    ]

  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1, maybe_preload_ens_to_address: 1]
  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.API.V2.{BlockView, TransactionView, WithdrawalView}
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.{Address, Hash, Transaction}
  alias Explorer.Chain.Address.Counters

  alias Explorer.Chain.Token.Instance
  alias Explorer.SmartContract.Helper, as: SmartContractHelper

  alias BlockScoutWeb.API.V2.CeloView
  alias Explorer.Chain.Celo.ElectionReward, as: CeloElectionReward
  alias Explorer.Chain.Celo.Reader, as: CeloReader

  alias Indexer.Fetcher.OnDemand.CoinBalance, as: CoinBalanceOnDemand
  alias Indexer.Fetcher.OnDemand.ContractCode, as: ContractCodeOnDemand
  alias Indexer.Fetcher.OnDemand.TokenBalance, as: TokenBalanceOnDemand

  case @chain_type do
    :celo ->
      @chain_type_transaction_necessity_by_association %{
        :gas_token => :optional
      }

    _ ->
      @chain_type_transaction_necessity_by_association %{}
  end

  @transaction_necessity_by_association [
    necessity_by_association:
      %{
        [created_contract_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] =>
          :optional,
        [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
        [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
        :block => :optional
      }
      |> Map.merge(@chain_type_transaction_necessity_by_association),
    api?: true
  ]

  @token_transfer_necessity_by_association [
    necessity_by_association: %{
      [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
      [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
      :block => :optional,
      :transaction => :optional,
      :token => :optional
    },
    api?: true
  ]

  @address_options [
    necessity_by_association: %{
      :names => :optional,
      :scam_badge => :optional,
      :token => :optional,
      :signed_authorization => :optional,
      :smart_contract => :optional
    },
    api?: true
  ]

  @nft_necessity_by_association [
    necessity_by_association: %{
      :token => :optional
    }
  ]

  @api_true [api?: true]

  @celo_election_rewards_options [
    necessity_by_association: %{
      [
        account_address: [
          :names,
          :smart_contract,
          proxy_implementations_association()
        ]
      ] => :optional,
      [
        associated_account_address: [
          :names,
          :smart_contract,
          proxy_implementations_association()
        ]
      ] => :optional
    },
    api?: true
  ]

  @spec contract_address_preloads() :: [keyword()]
  defp contract_address_preloads do
    chain_type_associations =
      case chain_type() do
        :filecoin -> Address.contract_creation_transaction_with_from_address_associations()
        _ -> Address.contract_creation_transaction_associations()
      end

    [:smart_contract | chain_type_associations]
  end

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
  Function to handle GET requests to `/api/v2/addresses/:address_hash_param` endpoint.
  Returns 200 on any valid address_hash, even if the address is not found in the database.
  """
  @spec address(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def address(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, address} ->
          fully_preloaded_address =
            Address.maybe_preload_smart_contract_associations(address, contract_address_preloads(), @api_true)

          implementations = SmartContractHelper.pre_fetch_implementations(fully_preloaded_address)

          CoinBalanceOnDemand.trigger_fetch(address)
          ContractCodeOnDemand.trigger_fetch(fully_preloaded_address)

          conn
          |> put_status(200)
          |> render(:address, %{
            address:
              %Address{fully_preloaded_address | proxy_implementations: implementations}
              |> maybe_preload_ens_to_address()
          })

        _ ->
          conn
          |> put_status(200)
          |> render(:address, %{
            address:
              %Address{
                hash: address_hash,
                names: [],
                scam_badge: nil,
                token: nil,
                signed_authorization: nil,
                smart_contract: nil
              }
              |> maybe_preload_ens_to_address()
          })
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/counters` endpoint.

  ## Parameters
  - conn: The connection struct (Plug.Conn.t()).
  - params: A map of parameters.

  ## Returns
  - `{:format, :error}` if provided address_hash is invalid.
  - `{:restricted_access, true}` if access is restricted.
  - `Plug.Conn.t()` if the operation is successful.
  """
  @spec counters(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def counters(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, address} ->
          {validation_count} = Counters.address_counters(address, @api_true)

          transactions_from_db = address.transactions_count || 0
          token_transfers_from_db = address.token_transfers_count || 0
          address_gas_usage_from_db = address.gas_used || 0

          json(conn, %{
            transactions_count: to_string(transactions_from_db),
            token_transfers_count: to_string(token_transfers_from_db),
            gas_usage_count: to_string(address_gas_usage_from_db),
            validations_count: to_string(validation_count)
          })

        _ ->
          json(conn, %{
            transactions_count: to_string(0),
            token_transfers_count: to_string(0),
            gas_usage_count: to_string(0),
            validations_count: to_string(0)
          })
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/token-balances` endpoint (retrieves the token balances for a given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the request parameters.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec token_balances(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def token_balances(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          token_balances =
            address_hash
            |> Chain.fetch_last_token_balances(@api_true |> fetch_scam_token_toggle(conn))

          Task.start_link(fn ->
            TokenBalanceOnDemand.trigger_fetch(address_hash)
          end)

          conn
          |> put_status(200)
          |> render(:token_balances, %{token_balances: token_balances})

        _ ->
          conn
          |> put_status(200)
          |> render(:token_balances, %{token_balances: []})
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/transactions` endpoint (retrieves transactions for a given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec transactions(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def transactions(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          options =
            @transaction_necessity_by_association
            |> Keyword.merge(paging_options(params))
            |> Keyword.merge(current_filter(params))
            |> Keyword.merge(address_transactions_sorting(params))

          results_plus_one = Transaction.address_to_transactions_without_rewards(address_hash, options, false)
          {transactions, next_page} = split_list_by_page(results_plus_one)

          next_page_params =
            next_page
            |> next_page_params(
              transactions,
              delete_parameters_from_next_page_params(params),
              &Transaction.address_transactions_next_page_params/1
            )

          conn
          |> put_status(200)
          |> put_view(TransactionView)
          |> render(:transactions, %{
            transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
            next_page_params: next_page_params
          })

        _ ->
          conn
          |> put_status(200)
          |> put_view(TransactionView)
          |> render(:transactions, %{
            transactions: [],
            next_page_params: nil
          })
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/token-transfers` endpoint (retrieves token transfers for a given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `{:not_found, {:error, :not_found}}` if token with provided address hash is not found.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec token_transfers(Plug.Conn.t(), map()) ::
          {:format, :error}
          | {:not_found, {:error, :not_found}}
          | {:restricted_access, true}
          | Plug.Conn.t()
  def token_transfers(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params),
         {:ok, token_address_hash} <- validate_optional_address_hash(params["token"], params),
         token_address_exists <- (token_address_hash && Chain.check_token_exists(token_address_hash)) || :ok do
      case {Chain.hash_to_address(address_hash, @address_options), token_address_exists} do
        {{:ok, _address}, :ok} ->
          paging_options = paging_options(params)

          options =
            @token_transfer_necessity_by_association
            |> Keyword.merge(paging_options)
            |> Keyword.merge(current_filter(params))
            |> Keyword.merge(token_transfers_types_options(params))
            |> Keyword.merge(token_address_hash: token_address_hash)
            |> fetch_scam_token_toggle(conn)

          results =
            address_hash
            |> Chain.address_hash_to_token_transfers_new(options)
            |> Chain.flat_1155_batch_token_transfers()
            |> Chain.paginate_1155_batch_token_transfers(paging_options)

          {token_transfers, next_page} = split_list_by_page(results)

          next_page_params =
            next_page
            |> token_transfers_next_page_params(token_transfers, delete_parameters_from_next_page_params(params))

          conn
          |> put_status(200)
          |> put_view(TransactionView)
          |> render(:token_transfers, %{
            token_transfers:
              token_transfers |> Instance.preload_nft(@api_true) |> maybe_preload_ens() |> maybe_preload_metadata(),
            next_page_params: next_page_params
          })

        _ ->
          conn
          |> put_status(200)
          |> put_view(TransactionView)
          |> render(:token_transfers, %{
            token_transfers: [],
            next_page_params: nil
          })
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/internal-transactions` endpoint (retrieves internal transactions for a given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec internal_transactions(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def internal_transactions(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          full_options =
            [
              necessity_by_association: %{
                [created_contract_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] =>
                  :optional,
                [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] =>
                  :optional,
                [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
              }
            ]
            |> Keyword.merge(paging_options(params))
            |> Keyword.merge(current_filter(params))
            |> Keyword.merge(@api_true)

          results_plus_one = Chain.address_to_internal_transactions(address_hash, full_options)
          {internal_transactions, next_page} = split_list_by_page(results_plus_one)

          next_page_params =
            next_page |> next_page_params(internal_transactions, delete_parameters_from_next_page_params(params))

          conn
          |> put_status(200)
          |> put_view(TransactionView)
          |> render(:internal_transactions, %{
            internal_transactions: internal_transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
            next_page_params: next_page_params
          })

        _ ->
          conn
          |> put_status(200)
          |> put_view(TransactionView)
          |> render(:internal_transactions, %{
            internal_transactions: [],
            next_page_params: nil
          })
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/logs` endpoint (retrieves logs for a given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec logs(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def logs(conn, %{"address_hash_param" => address_hash_string, "topic" => topic} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          prepared_topic = String.trim(topic)

          formatted_topic =
            if String.starts_with?(prepared_topic, "0x"), do: prepared_topic, else: "0x" <> prepared_topic

          options =
            params
            |> paging_options()
            |> Keyword.merge(topic: formatted_topic)
            |> Keyword.merge(
              necessity_by_association: %{
                [address: [:names, :smart_contract, proxy_implementations_association()]] => :optional
              }
            )
            |> Keyword.merge(@api_true)

          results_plus_one = Chain.address_to_logs(address_hash, false, options)

          {logs, next_page} = split_list_by_page(results_plus_one)

          next_page_params = next_page |> next_page_params(logs, delete_parameters_from_next_page_params(params))

          conn
          |> put_status(200)
          |> put_view(TransactionView)
          |> render(:logs, %{
            logs: logs |> maybe_preload_ens() |> maybe_preload_metadata(),
            next_page_params: next_page_params
          })

        _ ->
          conn
          |> put_status(200)
          |> put_view(TransactionView)
          |> render(:logs, %{
            logs: [],
            next_page_params: nil
          })
      end
    end
  end

  def logs(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          options = params |> paging_options() |> Keyword.merge(@api_true)

          results_plus_one = Chain.address_to_logs(address_hash, false, options)

          {logs, next_page} = split_list_by_page(results_plus_one)

          next_page_params = next_page |> next_page_params(logs, delete_parameters_from_next_page_params(params))

          conn
          |> put_status(200)
          |> put_view(TransactionView)
          |> render(:logs, %{
            logs: logs |> maybe_preload_ens() |> maybe_preload_metadata(),
            next_page_params: next_page_params
          })

        _ ->
          conn
          |> put_status(200)
          |> put_view(TransactionView)
          |> render(:logs, %{
            logs: [],
            next_page_params: nil
          })
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/blocks-validated` endpoint (retrieves validated by a given address blocks)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec blocks_validated(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def blocks_validated(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          full_options =
            [
              necessity_by_association: %{
                [miner: proxy_implementations_association()] => :optional,
                miner: :required,
                nephews: :optional,
                transactions: :optional,
                rewards: :optional
              }
            ]
            |> Keyword.merge(paging_options(params))
            |> Keyword.merge(@api_true)

          results_plus_one = Chain.get_blocks_validated_by_address(full_options, address_hash)
          {blocks, next_page} = split_list_by_page(results_plus_one)

          next_page_params = next_page |> next_page_params(blocks, delete_parameters_from_next_page_params(params))

          conn
          |> put_status(200)
          |> put_view(BlockView)
          |> render(:blocks, %{blocks: blocks, next_page_params: next_page_params})

        _ ->
          conn
          |> put_status(200)
          |> put_view(BlockView)
          |> render(:blocks, %{blocks: [], next_page_params: nil})
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/coin-balance-history` endpoint (retrieves coin balance history for given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec coin_balance_history(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def coin_balance_history(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, address} ->
          full_options = params |> paging_options() |> Keyword.merge(@api_true)

          results_plus_one = Chain.address_to_coin_balances(address, full_options)

          {coin_balances, next_page} = split_list_by_page(results_plus_one)

          next_page_params =
            next_page |> next_page_params(coin_balances, delete_parameters_from_next_page_params(params))

          conn
          |> put_status(200)
          |> render(:coin_balances, %{coin_balances: coin_balances, next_page_params: next_page_params})

        _ ->
          conn
          |> put_status(200)
          |> render(:coin_balances, %{coin_balances: [], next_page_params: nil})
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/coin-balance-history-by-day` endpoint (retrieves coin balance history by day for given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec coin_balance_history_by_day(Plug.Conn.t(), map()) ::
          {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def coin_balance_history_by_day(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          balances_by_day =
            address_hash
            |> Chain.address_to_balances_by_day(@api_true)

          conn
          |> put_status(200)
          |> render(:coin_balances_by_day, %{coin_balances_by_day: balances_by_day})

        _ ->
          conn
          |> put_status(200)
          |> render(:coin_balances_by_day, %{coin_balances_by_day: []})
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/tokens` endpoint (retrieves token balances for given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec tokens(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def tokens(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          results_plus_one =
            address_hash
            |> Chain.fetch_paginated_last_token_balances(
              params
              |> paging_options()
              |> Keyword.merge(token_transfers_types_options(params))
              |> Keyword.merge(@api_true)
              |> fetch_scam_token_toggle(conn)
            )

          Task.start_link(fn ->
            TokenBalanceOnDemand.trigger_fetch(address_hash)
          end)

          {tokens, next_page} = split_list_by_page(results_plus_one)

          next_page_params =
            next_page
            |> next_page_params(
              tokens,
              delete_parameters_from_next_page_params(params),
              &paging_params_with_fiat_value/1
            )

          conn
          |> put_status(200)
          |> render(:tokens, %{tokens: tokens, next_page_params: next_page_params})

        _ ->
          conn
          |> put_status(200)
          |> render(:tokens, %{tokens: [], next_page_params: nil})
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/withdrawals` endpoint (retrieves withdrawals for given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec withdrawals(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def withdrawals(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          options = @api_true |> Keyword.merge(paging_options(params))
          withdrawals_plus_one = address_hash |> Chain.address_hash_to_withdrawals(options)
          {withdrawals, next_page} = split_list_by_page(withdrawals_plus_one)

          next_page_params = next_page |> next_page_params(withdrawals, delete_parameters_from_next_page_params(params))

          conn
          |> put_status(200)
          |> put_view(WithdrawalView)
          |> render(:withdrawals, %{
            withdrawals: withdrawals |> maybe_preload_ens() |> maybe_preload_metadata(),
            next_page_params: next_page_params
          })

        _ ->
          conn
          |> put_status(200)
          |> put_view(WithdrawalView)
          |> render(:withdrawals, %{
            withdrawals: [],
            next_page_params: nil
          })
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses` endpoint (retrieves addresses list)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `Plug.Conn.t()` if the request is successful.
  """
  @spec addresses_list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def addresses_list(conn, params) do
    {addresses, next_page} =
      params
      |> paging_options()
      |> Keyword.merge(@api_true)
      |> Keyword.merge(addresses_sorting(params))
      |> Address.list_top_addresses()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, addresses, delete_parameters_from_next_page_params(params))

    exchange_rate = Market.get_coin_exchange_rate()
    total_supply = Chain.total_supply()

    conn
    |> put_status(200)
    |> render(:addresses, %{
      addresses: addresses |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params,
      exchange_rate: exchange_rate,
      total_supply: total_supply
    })
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/tabs-counters` endpoint (retrieves counter for each entity (max counter value is 51) for given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec tabs_counters(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def tabs_counters(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      counter_name_to_json_field_name = %{
        validations: :validations_count,
        transactions: :transactions_count,
        token_transfers: :token_transfers_count,
        token_balances: :token_balances_count,
        logs: :logs_count,
        withdrawals: :withdrawals_count,
        internal_transactions: :internal_transactions_count,
        celo_election_rewards: :celo_election_rewards_count
      }

      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          counters_json =
            address_hash
            |> Counters.address_limited_counters(@api_true)
            |> Enum.reduce(%{}, fn {counter_name, counter_value}, acc ->
              counter_name_to_json_field_name
              |> Map.fetch(counter_name)
              # credo:disable-for-next-line
              |> case do
                {:ok, json_field_name} ->
                  Map.put(acc, json_field_name, counter_value)

                :error ->
                  acc
              end
            end)

          conn
          |> put_status(200)
          |> json(counters_json)

        _ ->
          counters_json =
            counter_name_to_json_field_name
            |> Enum.reduce(%{}, fn {_counter_type, json_field}, acc ->
              Map.put(acc, json_field, 0)
            end)

          conn
          |> put_status(200)
          |> json(counters_json)
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/nft-list` endpoint (retrieves NFTs for given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec nft_list(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def nft_list(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          results_plus_one =
            Instance.nft_list(
              address_hash,
              params
              |> paging_options()
              |> Keyword.merge(nft_types_options(params))
              |> Keyword.merge(@api_true)
              |> Keyword.merge(@nft_necessity_by_association)
              |> fetch_scam_token_toggle(conn)
            )

          {nfts, next_page} = split_list_by_page(results_plus_one)

          next_page_params =
            next_page
            |> next_page_params(
              nfts,
              delete_parameters_from_next_page_params(params),
              &Instance.nft_list_next_page_params/1
            )

          conn
          |> put_status(200)
          |> render(:nft_list, %{token_instances: nfts, next_page_params: next_page_params})

        _ ->
          conn
          |> put_status(200)
          |> render(:nft_list, %{token_instances: [], next_page_params: nil})
      end
    end
  end

  @doc """
  Handles GET requests to `/api/v2/addresses/:address_hash_param/nft-collections` endpoint (retrieves NFTs grouped by collections for given address)

  ## Parameters

    - conn: The connection struct.
    - params: A map containing the parameters for the request.

  ## Returns

    - `{:format, :error}` if provided address_hash is invalid.
    - `{:restricted_access, true}` if access is restricted.
    - `Plug.Conn.t()` if the request is successful.
  """
  @spec nft_collections(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def nft_collections(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          results_plus_one =
            Instance.nft_collections(
              address_hash,
              params
              |> paging_options()
              |> Keyword.merge(nft_types_options(params))
              |> Keyword.merge(@api_true)
              |> Keyword.merge(@nft_necessity_by_association)
              |> fetch_scam_token_toggle(conn)
            )

          {collections, next_page} = split_list_by_page(results_plus_one)

          next_page_params =
            next_page
            |> next_page_params(
              collections,
              delete_parameters_from_next_page_params(params),
              &Instance.nft_collections_next_page_params/1
            )

          conn
          |> put_status(200)
          |> render(:nft_collections, %{collections: collections, next_page_params: next_page_params})

        _ ->
          conn
          |> put_status(200)
          |> render(:nft_collections, %{collections: [], next_page_params: nil})
      end
    end
  end

  @doc """
  Function to handle GET requests to `/api/v2/addresses/:address_hash_param/election-rewards` endpoint.
  """
  @spec celo_election_rewards(Plug.Conn.t(), map()) :: {:format, :error} | {:restricted_access, true} | Plug.Conn.t()
  def celo_election_rewards(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash} <- validate_address_hash(address_hash_string, params) do
      case Chain.hash_to_address(address_hash, @address_options) do
        {:ok, _address} ->
          full_options =
            @celo_election_rewards_options
            |> Keyword.merge(CeloElectionReward.address_paging_options(params))

          results_plus_one = CeloReader.address_hash_to_election_rewards(address_hash, full_options)

          {rewards, next_page} = split_list_by_page(results_plus_one)

          next_page_params =
            next_page_params(
              next_page,
              rewards,
              delete_parameters_from_next_page_params(params),
              &CeloElectionReward.to_address_paging_params/1
            )

          conn
          |> put_status(200)
          |> put_view(CeloView)
          |> render(:celo_election_rewards, %{
            rewards: rewards,
            next_page_params: next_page_params
          })

        _ ->
          conn
          |> put_status(200)
          |> put_view(CeloView)
          |> render(:celo_election_rewards, %{
            rewards: [],
            next_page_params: nil
          })
      end
    end
  end

  # Checks if this address hash string is valid, and this address is not prohibited.
  # Returns the `{:ok, address_hash}` if address hash passed all the checks.
  # Returns {:ok, _} response even if the address is not present in the database.
  @spec validate_address_hash(String.t(), any()) ::
          {:format, :error}
          | {:restricted_access, true}
          | {:ok, Hash.t()}
  defp validate_address_hash(address_hash_string, params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      {:ok, address_hash}
    end
  end

  # Checks if this address hash string is valid, and this address is not prohibited.
  # Returns the `{:ok, nil}` if first argument is `nil`.
  # Returns the `{:ok, address_hash}` if address hash passed all the checks.
  # Returns {:ok, _} response even if the address is not present in the database.
  @spec validate_optional_address_hash(nil | String.t(), any()) ::
          {:format, :error}
          | {:restricted_access, true}
          | {:ok, nil | Hash.t()}
  defp validate_optional_address_hash(address_hash_string, params) do
    case address_hash_string do
      nil ->
        {:ok, nil}

      _ ->
        validate_address_hash(address_hash_string, params)
    end
  end
end
