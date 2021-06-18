require Logger

alias HTTPoison.Response

defmodule Explorer.Advertisement do
  @moduledoc """
  Advertisement helpers
  """
  def get_text_ad_data do
    ad_api_key = "19260bf627546ab7242"
    ad_api_url = "https://request-global.czilladx.com/serve/native.php?z=#{ad_api_key}"

    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.get(ad_api_url, headers) do
      {:ok, %Response{body: body, status_code: 200}} ->
        Logger.info("Text banner advertisement")
        Logger.info(body)

        case Jason.decode(body) do
          {:ok, body_decoded} ->
            ad = body_decoded |> Map.get("ad")
            name = ad |> Map.get("name")
            img_url = ad |> Map.get("thumbnail")
            short_description = ad |> Map.get("description_short")
            cta_button = ad |> Map.get("cta_button")
            url = ad |> Map.get("url")
            %{name: name, img_url: img_url, short_description: short_description, cta_button: cta_button, url: url}

          error ->
            Logger.info("Text banner advertisement error 1")
            Logger.info(error)
            nil
        end

      {:ok, response} ->
        Logger.info("Text banner advertisement error 2")
        Logger.info(response)
        nil

      error ->
        Logger.info("Text banner advertisement error 3")
        Logger.info(error)
        nil
    end
  end
end
