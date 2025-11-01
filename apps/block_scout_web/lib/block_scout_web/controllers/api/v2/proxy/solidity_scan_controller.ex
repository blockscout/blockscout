defmodule BlockScoutWeb.API.V2.Proxy.SolidityScanController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelper
  alias Explorer.Chain
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.ThirdPartyIntegrations.SolidityScan

  @api_true [api?: true]

  @doc """
  /api/v2/proxy/3rdparty/solidityscan/smart-contracts/:address_hash_string/report logic
  """
  @spec solidityscan_report(Plug.Conn.t(), map()) ::
          {:address, {:error, :not_found}}
          | {:format_address, :error}
          | {:is_empty_response, true}
          | {:is_smart_contract, false | nil}
          | {:restricted_access, true}
          | {:is_verified_smart_contract, false}
          | {:language, :vyper}
          | Plug.Conn.t()
  def solidityscan_report(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format_address, {:ok, address_hash}} <- {:format_address, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:address, {:ok, address}} <- {:address, Chain.hash_to_address(address_hash)},
         {:is_smart_contract, true} <- {:is_smart_contract, Address.smart_contract?(address)},
         smart_contract = SmartContract.address_hash_to_smart_contract(address_hash, @api_true),
         {:is_verified_smart_contract, true} <- {:is_verified_smart_contract, !is_nil(smart_contract)},
         {:language, language} when language != :vyper <- {:language, SmartContract.language(smart_contract)},
         response = SolidityScan.solidityscan_request(address_hash_string),
         {:is_empty_response, false} <- {:is_empty_response, is_nil(response)} do
      conn
      |> put_status(200)
      |> json(response)
    end
  end
end
