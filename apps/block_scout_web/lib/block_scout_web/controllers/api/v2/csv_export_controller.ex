defmodule BlockScoutWeb.API.V2.CSVExportController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelper
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.CSVExport.Helper, as: CSVHelper
  alias Plug.Conn

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @options [paging_options: %PagingOptions{page_size: CSVHelper.limit()}, api?: true]
  @api_true [api?: true]

  @doc """
  Performs CSV export of token holders for a given address
  Endpoint: `/api/v2/tokens/:address_hash_param/holders/csv`
  """
  @spec export_token_holders(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def export_token_holders(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:recaptcha, true} <-
           {:recaptcha,
            Application.get_env(:block_scout_web, :recaptcha)[:is_disabled] ||
              CSVHelper.captcha_helper().recaptcha_passed?(params["recaptcha_response"])},
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)} do
      token_holders = Chain.fetch_token_holders_from_token_hash_for_csv(address_hash, @options)

      token_holders
      |> CurrentTokenBalance.to_csv_format(token)
      |> CSVHelper.dump_to_stream()
      |> Enum.reduce_while(put_resp_params(conn), fn chunk, conn ->
        case Conn.chunk(conn, chunk) do
          {:ok, conn} ->
            {:cont, conn}

          {:error, :closed} ->
            {:halt, conn}
        end
      end)
    end
  end

  @spec put_resp_params(Plug.Conn.t()) :: Plug.Conn.t()
  def put_resp_params(conn) do
    conn
    |> put_resp_content_type("application/csv")
    |> put_resp_header("content-disposition", "attachment;")
    |> put_resp_cookie("csv-downloaded", "true", max_age: 86_400, http_only: false)
    |> send_chunked(200)
  end
end
