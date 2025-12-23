defmodule BlockScoutWeb.API.V2.ConfigController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Explorer.Chain.SmartContract
  alias OpenApiSpex.Schema

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["config"])

  operation :backend_version,
    summary: "Get backend version",
    description: "Returns application backend version string.",
    parameters: base_params(),
    responses: [
      ok:
        {"Backend version.", "application/json",
         %Schema{type: :object, properties: %{backend_version: %Schema{type: :string, nullable: true}}}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  def backend_version(conn, _params) do
    backend_version = Application.get_env(:block_scout_web, :version)

    conn
    |> put_status(200)
    |> render(:backend_version, %{version: backend_version})
  end

  operation :csv_export,
    summary: "CSV export limits",
    description: "Returns configured limits for CSV export endpoints.",
    parameters: base_params(),
    responses: [
      ok:
        {"CSV export limits.", "application/json",
         %Schema{type: :object, properties: %{limit: %Schema{type: :integer}}}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  def csv_export(conn, _params) do
    limit = Application.get_env(:explorer, :csv_export_limit)

    conn
    |> put_status(200)
    |> json(%{limit: limit})
  end

  operation :indexer,
    summary: "Indexer configuration",
    description: "Returns config of indexer.",
    parameters: base_params(),
    responses: [
      ok:
        {"Indexer configuration.", "application/json",
         %Schema{
           type: :object,
           properties: %{
             indexer_enabled: %Schema{type: :boolean},
             internal_transactions_fetcher_enabled: %Schema{type: :boolean},
             pending_transactions_fetcher_enabled: %Schema{type: :boolean},
             token_instance_retry_fetcher_enabled: %Schema{type: :boolean},
             token_instance_sanitize_fetcher_enabled: %Schema{type: :boolean},
             block_reward_fetcher_enabled: %Schema{type: :boolean}
           }
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  def indexer(conn, _params) do
    indexer_enabled? = System.get_env("DISABLE_INDEXER") !== "true"

    internal_transactions_fetcher_enabled? =
      indexer_enabled? &&
        not Application.get_env(:indexer, Indexer.Fetcher.InternalTransaction.Supervisor)[:disabled?]

    pending_transactions_fetcher_enabled? =
      indexer_enabled? &&
        not Application.get_env(:indexer, Indexer.Fetcher.PendingTransaction.Supervisor)[:disabled?]

    block_reward_fetcher_enabled? =
      indexer_enabled? &&
        not Application.get_env(:indexer, Indexer.Fetcher.BlockReward.Supervisor)[:disabled?]

    token_instance_retry_fetcher_enabled? =
      indexer_enabled? &&
        not Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Retry.Supervisor)[:disabled?]

    token_instance_sanitize_fetcher_enabled? =
      indexer_enabled? &&
        not Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Sanitize.Supervisor)[:disabled?]

    conn
    |> put_status(200)
    |> json(%{
      indexer_enabled: indexer_enabled?,
      internal_transactions_fetcher_enabled: internal_transactions_fetcher_enabled?,
      pending_transactions_fetcher_enabled: pending_transactions_fetcher_enabled?,
      block_reward_fetcher_enabled: block_reward_fetcher_enabled?,
      token_instance_retry_fetcher_enabled: token_instance_retry_fetcher_enabled?,
      token_instance_sanitize_fetcher_enabled: token_instance_sanitize_fetcher_enabled?
    })
  end

  operation :public_metrics,
    summary: "Public metrics configuration",
    description: "Returns update period / configuration for public metrics.",
    parameters: base_params(),
    responses: [
      ok:
        {"Public metrics config.", "application/json",
         %Schema{type: :object, properties: %{update_period_hours: %Schema{type: :integer}}}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  def public_metrics(conn, _params) do
    public_metrics_update_period_hours =
      Application.get_env(:explorer, Explorer.Chain.Metrics.PublicMetrics)[:update_period_hours]

    conn
    |> put_status(200)
    |> json(%{update_period_hours: public_metrics_update_period_hours})
  end

  operation :celo,
    summary: "Celo chain configuration",
    description: "Returns Celo-specific configuration (l2 migration block).",
    parameters: base_params(),
    responses: [
      ok:
        {"Celo config.", "application/json",
         %Schema{type: :object, properties: %{l2_migration_block: %Schema{type: :integer, nullable: true}}}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  def celo(conn, _params) do
    config = Application.get_env(:explorer, :celo)

    conn
    |> put_status(200)
    |> json(%{l2_migration_block: config[:l2_migration_block]})
  end

  operation :languages_list,
    summary: "Smart contract languages list",
    description: "Returns list of smart contract languages supported by the database schema.",
    parameters: base_params(),
    responses: [
      ok:
        {"Smart contract languages.", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             languages: %OpenApiSpex.Schema{
               type: :array,
               items: Schemas.SmartContract.Language
             }
           }
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/config/smart-contracts/languages` endpoint.
  """
  @spec languages_list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def languages_list(conn, _params) do
    conn
    |> put_status(200)
    |> json(%{languages: SmartContract.language_strings()})
  end
end
