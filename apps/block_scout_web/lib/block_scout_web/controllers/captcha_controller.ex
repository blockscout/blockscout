defmodule BlockScoutWeb.CaptchaController do
  use BlockScoutWeb, :controller
  alias Plug.Conn

  def index(conn, %{"captchaResponse" => captcha_response, "type" => "JSON"}) do
    site_key = Application.get_env(:block_scout_web, :re_captcha_site_key)
    gcp_project_id = Application.get_env(:block_scout_web, :re_captcha_project_id)
    api_key = Application.get_env(:block_scout_web, :re_captcha_api_key)

    {:ok, body} =
      %{
        event: %{
          token: captcha_response,
          siteKey: site_key
        }
      }
      |> Jason.encode()

    url = "https://recaptchaenterprise.googleapis.com/v1beta1/projects/#{gcp_project_id}/assessments?key=#{api_key}"
    headers = [{"Content-type", "application/json"}]

    case HTTPoison.post(url, body, headers, []) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Conn.resp(conn, status_code, body)
    end
  end
end
