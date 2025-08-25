defmodule BlockScoutWeb.API.V2.Ethereum.DepositView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain.Beacon.Deposit

  def render("deposits.json", %{deposits: deposits, next_page_params: next_page_params}) do
    %{"items" => Enum.map(deposits, &prepare_deposit/1), "next_page_params" => next_page_params}
  end

  @spec prepare_deposit(Deposit.t()) :: map()
  def prepare_deposit(deposit) do
    %{
      "index" => deposit.index,
      "transaction_hash" => deposit.transaction_hash,
      "block_hash" => deposit.block_hash,
      "block_number" => deposit.block_number,
      "block_timestamp" => deposit.block_timestamp,
      "pubkey" => deposit.pubkey,
      "withdrawal_credentials" => deposit.withdrawal_credentials,
      "withdrawal_address" =>
        Helper.address_with_info(
          nil,
          deposit.withdrawal_address,
          deposit.withdrawal_address_hash,
          false
        ),
      "amount" => deposit.amount,
      "signature" => deposit.signature,
      "status" => deposit.status,
      "from_address" =>
        Helper.address_with_info(
          nil,
          deposit.from_address,
          deposit.from_address_hash,
          false
        )
    }
  end
end
