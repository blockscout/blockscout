defmodule BlockScoutWeb.Schemas.API.V2.Account do
  @moduledoc """
  Provides OpenAPI specification schemas for account-related API V2 endpoints.

  This module defines request body and response schemas used by the account
  authentication endpoints. It supports two authentication flows:

  - **Email OTP authentication**: Users request a one-time password via email
    and confirm it to authenticate
  - **Wallet authentication**: Users authenticate using Sign-In With Ethereum
    (SIWE) by signing a message with their wallet

  The schemas defined here are used with OpenApiSpex to document and validate
  the API request and response payloads in the BlockScout API documentation.
  """

  @spec send_otp_request_body() :: OpenApiSpex.RequestBody.t()
  def send_otp_request_body do
    %OpenApiSpex.RequestBody{
      content: %{
        "application/json" => %OpenApiSpex.MediaType{
          schema: %OpenApiSpex.Schema{
            type: :object,
            properties: %{
              email: %OpenApiSpex.Schema{type: :string, format: :email}
            },
            required: [
              :email
            ]
          }
        }
      }
    }
  end

  @spec authenticate_via_wallet_request_body() :: OpenApiSpex.RequestBody.t()
  def authenticate_via_wallet_request_body do
    %OpenApiSpex.RequestBody{
      content: %{
        "application/json" => %OpenApiSpex.MediaType{
          schema: %OpenApiSpex.Schema{
            type: :object,
            properties: %{
              message: %OpenApiSpex.Schema{type: :string},
              signature: %OpenApiSpex.Schema{type: :string}
            },
            required: [:message, :signature]
          }
        }
      }
    }
  end

  @spec confirm_otp_request_body() :: OpenApiSpex.RequestBody.t()
  def confirm_otp_request_body do
    %OpenApiSpex.RequestBody{
      content: %{
        "application/json" => %OpenApiSpex.MediaType{
          schema: %OpenApiSpex.Schema{
            type: :object,
            properties: %{
              email: %OpenApiSpex.Schema{type: :string},
              otp: %OpenApiSpex.Schema{type: :string}
            },
            required: [
              :email,
              :otp
            ]
          }
        }
      }
    }
  end

  @spec siwe_message_response_schema() :: OpenApiSpex.Schema.t()
  def siwe_message_response_schema do
    %OpenApiSpex.Schema{
      type: :object,
      properties: %{
        siwe_message: %OpenApiSpex.Schema{type: :string}
      },
      required: [:siwe_message]
    }
  end
end
