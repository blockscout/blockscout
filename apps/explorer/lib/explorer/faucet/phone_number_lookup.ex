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

    case parsed_resp_body do
      %{"carrier" => %{"type" => type}} ->
        if type == "voip" do
          {:error, :virtual}
        else
          {:ok, :mobile}
        end

      _ ->
        {:error, :unknown}
    end
  end
end
