defmodule Explorer.Faucet.PhoneNumberLookup do
  @moduledoc """
  Check phone number in Twilio Lookup API https://www.twilio.com/docs/lookup/api.
  """

  use Tesla

  plug(Tesla.Middleware.BaseUrl, "https://lookups.twilio.com")

  plug(Tesla.Middleware.BasicAuth,
    username: System.get_env("TWILIO_ACCOUNT_SID"),
    password: System.get_env("TWILIO_AUTH_TOKEN")
  )

  def check(sanitized_phone_number) do
    lookup_endpoint = "/v1/PhoneNumbers/+#{sanitized_phone_number}?Type=carrier"
    {:ok, response} = get(lookup_endpoint)

    parsed_resp_body = Jason.decode!(response.body)

    prohibited_carriers = get_prohibited_carriers()

    case parsed_resp_body do
      %{"carrier" => %{"name" => name, "type" => type}} ->
        cond do
          type == "voip" -> {:error, :virtual}
          Enum.member?(prohibited_carriers, name) -> {:error, :prohibited_operator}
          true -> {:ok, :mobile}
        end

      _ ->
        {:error, :unknown}
    end
  end

  defp get_prohibited_carriers() do
    env_var = "TWILIO_PROHIBITED_CARRIERS"

    env_var
    |> System.get_env("")
    |> String.split(",")
    |> Enum.map(fn env_var ->
      env_var
      |> String.trim()
    end)
  end
end
