defmodule BlockScoutWeb.API.V2.WithdrawalView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain.Withdrawal

  def render("withdrawals.json", %{withdrawals: withdrawals, next_page_params: next_page_params}) do
    %{"items" => Enum.map(withdrawals, &prepare_withdrawal(&1)), "next_page_params" => next_page_params}
  end

  @spec prepare_withdrawal(Withdrawal.t()) :: map()
  def prepare_withdrawal(%Withdrawal{block: %Ecto.Association.NotLoaded{}} = withdrawal) do
    %{
      "index" => withdrawal.index,
      "validator_index" => withdrawal.validator_index,
      "receiver" => Helper.address_with_info(withdrawal.address, withdrawal.address_hash),
      "amount" => withdrawal.amount
    }
  end

  def prepare_withdrawal(%Withdrawal{address: %Ecto.Association.NotLoaded{}} = withdrawal) do
    %{
      "index" => withdrawal.index,
      "validator_index" => withdrawal.validator_index,
      "block_number" => withdrawal.block.number,
      "amount" => withdrawal.amount,
      "timestamp" => withdrawal.block.timestamp
    }
  end

  def prepare_withdrawal(%Withdrawal{} = withdrawal) do
    %{
      "index" => withdrawal.index,
      "validator_index" => withdrawal.validator_index,
      "block_number" => withdrawal.block.number,
      "receiver" => Helper.address_with_info(withdrawal.address, withdrawal.address_hash),
      "amount" => withdrawal.amount,
      "timestamp" => withdrawal.block.timestamp
    }
  end
end
