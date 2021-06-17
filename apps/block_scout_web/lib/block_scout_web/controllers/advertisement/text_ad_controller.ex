defmodule BlockScoutWeb.Advertisement.TextAdController do
  use BlockScoutWeb, :controller

  alias HTTPoison.Response

  def index(conn, _params) do
    # todo
    ad_api_key = "19260bf627546ab7242"
    ad_api_url = "https://request-global.czilladx.com/serve/native.php?z=#{ad_api_key}"

    case HTTPoison.get(ad_api_url) do
      {:ok, %Response{body: body, status_code: 200}} ->
        case Jason.decode(body) do
          {:ok, body_decoded} ->
            title = Map.get(body_decoded, "title")
            render(conn, "index.html", title: title)

          _ ->
            render(conn, "empty.html")
        end

      _ ->
        render(conn, "empty.html")
    end
  end
end
