defmodule BlockScoutWeb.API.V2.SmartContractController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  use Utils.RuntimeEnvHelper,
    chain_type: [:explorer, :chain_type]

  import BlockScoutWeb.Chain,
    only: [
      fetch_scam_token_toggle: 2,
      next_page_params: 4,
      split_list_by_page: 1
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      current_filter: 1,
      search_query: 1
    ]

  import Explorer.PagingOptions,
    only: [
      default_paging_options: 0
    ]

  import Explorer.Helper,
    only: [
      parse_integer: 1,
      safe_parse_non_negative_integer: 1
    ]

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.Schemas.API.V2.General
  alias Explorer.Chain
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.Chain.SmartContract.AuditReport
  alias Explorer.SmartContract.Helper, as: SmartContractHelper
  alias Explorer.SmartContract.Solidity.PublishHelper

  @api_true [api?: true]

  tags(["smart-contracts"])

  operation :smart_contract,
    summary: "Smart contract",
    description: "Returns details for a smart contract address.",
    parameters: [address_hash_param() | base_params()],
    responses: [
      ok: {"Smart contract", "application/json", BlockScoutWeb.Schemas.API.V2.SmartContract}
    ]

  @doc """
    GET /api/v2/smart-contracts/:address_hash
  """
  @spec smart_contract(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def smart_contract(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         _ <- PublishHelper.sourcify_check(address_hash_string),
         {:not_found, {:ok, address}} <-
           {:not_found, Chain.find_contract_address(address_hash, smart_contract_address_options())} do
      implementations = SmartContractHelper.pre_fetch_implementations(address)

      conn
      |> put_status(200)
      |> render(:smart_contract, %{address: %Address{address | proxy_implementations: implementations}})
    end
  end

  operation :smart_contracts_list,
    summary: "Smart contracts list",
    description:
      "Returns a paginated list of verified smart contract addresses. Supports search, filtering and pagination keys.",
    parameters:
      base_params() ++
        [
          %OpenApiSpex.Parameter{
            name: "hash",
            in: :query,
            description: "Address hash used as pagination key",
            required: false,
            schema: %OpenApiSpex.Schema{type: :string}
          },
          %OpenApiSpex.Parameter{
            name: "transactions_count",
            in: :query,
            description: "Transactions count used as pagination key",
            required: false,
            schema: %OpenApiSpex.Schema{type: :integer}
          },
          %OpenApiSpex.Parameter{
            name: "coin_balance",
            in: :query,
            description: "Coin balance used as pagination key",
            required: false,
            schema: %OpenApiSpex.Schema{type: :integer}
          },
          %OpenApiSpex.Parameter{
            name: "smart_contract_id",
            in: :query,
            description: "Smart contract id used as pagination key",
            required: false,
            schema: %OpenApiSpex.Schema{type: :integer}
          },
          %OpenApiSpex.Parameter{
            name: "sort",
            in: :query,
            description: "Sort field (e.g. balance, transactions_count)",
            required: false,
            schema: %OpenApiSpex.Schema{type: :string}
          },
          %OpenApiSpex.Parameter{
            name: "order",
            in: :query,
            description: "Sort order (asc or desc)",
            required: false,
            schema: %OpenApiSpex.Schema{type: :string}
          },
          %OpenApiSpex.Parameter{
            name: "q",
            in: :query,
            description: "Search query",
            required: false,
            schema: %OpenApiSpex.Schema{type: :string}
          },
          %OpenApiSpex.Parameter{
            name: "filter",
            in: :query,
            description: "Filter to apply",
            required: false,
            schema: %OpenApiSpex.Schema{type: :string}
          }
        ] ++ define_paging_params(["smart_contract_id", "items_count"]),
    responses: [
      ok:
        {"Smart contracts", "application/json",
         paginated_response(
           items: BlockScoutWeb.Schemas.API.V2.SmartContract,
           next_page_params_example: %{
             "smart_contract_id" => 1_947_801,
             "items_count" => 50
           },
           title_prefix: "SmartContracts"
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/smart-contracts` endpoint.
  """
  @spec smart_contracts_list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def smart_contracts_list(conn, params) do
    full_options =
      verified_smart_contract_addresses_options()
      |> Keyword.merge(current_filter(params))
      |> Keyword.merge(search_query(params))
      |> Keyword.merge(smart_contract_addresses_paging_options(params))
      |> Keyword.merge(smart_contract_addresses_sorting(params))
      |> fetch_scam_token_toggle(conn)

    addresses_plus_one = SmartContract.verified_contract_addresses(full_options)
    {addresses, next_page} = split_list_by_page(addresses_plus_one)

    # If no sorting options are provided, we sort by `id` descending only. If
    # there are some sorting options supplied, we sort by `:hash` ascending as a
    # secondary key.
    pager =
      full_options
      |> Keyword.get(:sorting)
      |> if do
        &smart_contract_addresses_paging_params/1
      else
        &%{smart_contract_id: &1.smart_contract.id}
      end

    next_page_params =
      next_page
      |> next_page_params(
        addresses,
        params,
        pager
      )

    conn
    |> put_status(200)
    |> render(:smart_contracts, %{
      addresses: addresses,
      next_page_params: next_page_params
    })
  end

  operation :smart_contracts_counters,
    summary: "Smart contracts counters",
    description: "Returns counts for smart contracts and related metrics.",
    parameters: base_params(),
    responses: [
      ok: {"Smart contracts counters", "application/json", BlockScoutWeb.Schemas.API.V2.SmartContract.Counters},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/smart-contracts/counters` endpoint.
  """
  @spec smart_contracts_counters(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def smart_contracts_counters(conn, _params) do
    conn
    |> json(%{
      smart_contracts: Chain.count_contracts_from_cache(@api_true),
      new_smart_contracts_24h: Chain.count_new_contracts_from_cache(@api_true),
      verified_smart_contracts: Chain.count_verified_contracts_from_cache(@api_true),
      new_verified_smart_contracts_24h: Chain.count_new_verified_contracts_from_cache(@api_true)
    })
  end

  operation :audit_reports_list,
    summary: "Audit reports list",
    description: "Returns audit reports for a given smart contract address.",
    parameters: [address_hash_param() | base_params()],
    responses: [
      ok:
        {"Audit reports", "application/json",
         %Schema{
           description: "List of smart-contract's audit reports",
           type: :array,
           items: BlockScoutWeb.Schemas.API.V2.SmartContract.AuditReport
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    GET /api/v2/smart-contracts/{address_hash}/audit-reports
  """
  @spec audit_reports_list(Plug.Conn.t(), map()) ::
          {:format, :error}
          | {:not_found, nil | Explorer.Chain.SmartContract.t()}
          | {:restricted_access, true}
          | Plug.Conn.t()
  def audit_reports_list(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, address_hash, _smart_contract} <- validate_smart_contract(params, address_hash_string) do
      reports = AuditReport.get_audit_reports_by_smart_contract_address_hash(address_hash, @api_true)

      conn
      |> render(:audit_reports, %{reports: reports})
    end
  end

  operation :audit_report_submission,
    summary: "Submit audit report",
    description: "Submits an audit report for a given smart contract address.",
    parameters: [address_hash_param() | base_params()],
    request_body: General.audit_report_request_body(),
    responses: [
      ok:
        {"OK", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             message: %Schema{type: :string}
           }
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    POST /api/v2/smart-contracts/{address_hash}/audit-reports
  """
  @spec audit_report_submission(Plug.Conn.t(), map()) ::
          {:error, Ecto.Changeset.t()}
          | {:format, :error}
          | {:not_found, nil | Explorer.Chain.SmartContract.t()}
          | {:recaptcha, any()}
          | {:restricted_access, true}
          | Plug.Conn.t()
  def audit_report_submission(conn, %{"address_hash" => address_hash_string} = params) do
    with {:disabled, true} <- {:disabled, Application.get_env(:explorer, :air_table_audit_reports)[:enabled]},
         {:ok, address_hash, _smart_contract} <- validate_smart_contract(params, address_hash_string),
         audit_report_params <- %{
           address_hash: address_hash,
           submitter_name: params["submitter_name"],
           submitter_email: params["submitter_email"],
           is_project_owner: params["is_project_owner"],
           project_name: params["project_name"],
           project_url: params["project_url"],
           audit_company_name: params["audit_company_name"],
           audit_report_url: params["audit_report_url"],
           audit_publish_date: params["audit_publish_date"],
           comment: params["comment"]
         },
         {:ok, _} <- AuditReport.create(audit_report_params) do
      conn
      |> put_status(200)
      |> json(%{message: "OK"})
    end
  end

  @spec contract_creation_transaction_associations() :: [keyword()]
  defp contract_creation_transaction_associations do
    case chain_type() do
      :filecoin ->
        Address.contract_creation_transaction_with_from_address_associations()

      _ ->
        Address.contract_creation_transaction_associations()
    end
  end

  @spec smart_contract_address_options() :: keyword()
  defp smart_contract_address_options do
    [
      necessity_by_association: %{
        [smart_contract: :smart_contract_additional_sources] => :optional,
        contract_creation_transaction_associations() => :optional
      }
    ]
    |> Keyword.merge(@api_true)
  end

  @spec verified_smart_contract_addresses_options() :: keyword()
  defp verified_smart_contract_addresses_options do
    [
      necessity_by_association: %{
        [:token, :names, :proxy_implementations] => :optional,
        contract_creation_transaction_associations() => :optional
      }
    ]
    |> Keyword.merge(@api_true)
  end

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
  Builds paging options for smart contract addresses based on request
  parameters.

  ## Returns
  If 'hash', 'transactions_count', and 'coin_balance' parameters are provided,
  uses them as pagination keys for address-based sorting. If 'smart_contract_id'
  parameter is provided, uses it as pagination key for smart contract ID-based
  sorting. Otherwise, returns default paging options.

  ## Examples
      iex> smart_contract_addresses_paging_options(%{"hash" => "0x123...", "transactions_count" => "100", "coin_balance" => "1000"})
      [paging_options: %{key: %{hash: ..., transactions_count: 100, fetched_coin_balance: 1000}}]

      iex> smart_contract_addresses_paging_options(%{"smart_contract_id" => "42"})
      [paging_options: %{key: %{id: 42}}]

      iex> smart_contract_addresses_paging_options(%{})
      [paging_options: %{}]
  """
  @spec smart_contract_addresses_paging_options(%{required(String.t()) => String.t()}) ::
          [paging_options: map()]
  def smart_contract_addresses_paging_options(params) do
    options = do_smart_contract_addresses_paging_options(params)
    [paging_options: default_paging_options() |> Map.merge(options)]
  end

  @spec do_smart_contract_addresses_paging_options(%{required(String.t()) => String.t()}) :: map()
  defp do_smart_contract_addresses_paging_options(%{"hash" => hash_string} = params) do
    hash_string
    |> Chain.string_to_address_hash()
    |> case do
      {:ok, address_hash} ->
        transactions_count = parse_integer(params["transactions_count"])
        coin_balance = parse_integer(params["coin_balance"])

        %{
          key: %{
            hash: address_hash,
            transactions_count: transactions_count,
            fetched_coin_balance: coin_balance
          }
        }

      _ ->
        %{}
    end
  end

  defp do_smart_contract_addresses_paging_options(%{"smart_contract_id" => smart_contract_id}) do
    smart_contract_id
    |> safe_parse_non_negative_integer()
    |> case do
      {:ok, id} -> %{key: %{id: id}}
      _ -> %{}
    end
  end

  defp do_smart_contract_addresses_paging_options(_params), do: %{}

  # Extracts pagination parameters from an Address struct for use in the next page
  # URL.

  # ## Returns
  # A map with string keys that can be used as query parameters.

  # ## Examples
  #     iex> address = %Explorer.Chain.Address{hash: "0x123...", transactions_count: 100, fetched_coin_balance: 1000}
  #     iex> smart_contract_addresses_paging_params(address)
  #     %{"hash" => "0x123...", "transactions_count" => 100, "coin_balance" => 1000}
  @spec smart_contract_addresses_paging_params(Explorer.Chain.Address.t()) :: %{
          required(String.t()) => any()
        }
  defp smart_contract_addresses_paging_params(%Explorer.Chain.Address{
         hash: address_hash,
         transactions_count: transactions_count,
         fetched_coin_balance: coin_balance
       }) do
    %{
      "hash" => address_hash,
      "transactions_count" => transactions_count,
      "coin_balance" => coin_balance
    }
  end

  @spec smart_contract_addresses_sorting(%{required(String.t()) => String.t()}) :: [
          {:sorting, list()}
        ]
  defp smart_contract_addresses_sorting(%{"sort" => sort_field, "order" => order}) do
    {sort_field, order}
    |> case do
      {"balance", "asc"} -> {:ok, [{:asc_nulls_first, :fetched_coin_balance}]}
      {"balance", "desc"} -> {:ok, [{:desc_nulls_last, :fetched_coin_balance}]}
      {"transactions_count", "asc"} -> {:ok, [{:asc_nulls_first, :transactions_count}]}
      {"transactions_count", "desc"} -> {:ok, [{:desc_nulls_last, :transactions_count}]}
      _ -> :error
    end
    |> case do
      {:ok, sorting_params} ->
        [sorting: sorting_params]

      :error ->
        []
    end
  end

  defp smart_contract_addresses_sorting(_), do: []

  defp validate_smart_contract(params, address_hash_string) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {smart_contract, _}} when not is_nil(smart_contract) <-
           {:not_found, SmartContract.address_hash_to_smart_contract_with_bytecode_twin(address_hash, @api_true)} do
      {:ok, address_hash, smart_contract}
    end
  end
end
