defmodule BlockScoutWeb.AddressContractVerificationView do
  use BlockScoutWeb, :view
  alias BlockScoutWeb.ApiRouter.Helpers

  def api_v1_address_contract_verification_path(conn, action) do
    "/api" <> Helpers.api_v1_address_contract_verification_path(conn, action)
  end
end
