defmodule BlockScoutWeb.API.V2.ValidatorView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper

  def render("stability_validators.json", %{validators: validators, next_page_params: next_page_params}) do
    %{"items" => Enum.map(validators, &prepare_stability_validator(&1)), "next_page_params" => next_page_params}
  end

  def render("blackfort_validators.json", %{validators: validators, next_page_params: next_page_params}) do
    %{"items" => Enum.map(validators, &prepare_blackfort_validator(&1)), "next_page_params" => next_page_params}
  end

  def render("zilliqa_validators.json", %{validators: validators, next_page_params: next_page_params}) do
    %{"items" => Enum.map(validators, &prepare_zilliqa_validator(&1)), "next_page_params" => next_page_params}
  end

  def render("zilliqa_validator.json", %{validator: validator}) do
    validator
    |> prepare_zilliqa_validator()
    |> Map.merge(%{
      "peer_id" => validator.peer_id,
      "control_address" =>
        Helper.address_with_info(nil, validator.control_address, validator.control_address_hash, true),
      "reward_address" => Helper.address_with_info(nil, validator.reward_address, validator.reward_address_hash, true),
      "signing_address" =>
        Helper.address_with_info(nil, validator.signing_address, validator.signing_address_hash, true),
      "added_at_block_number" => validator.added_at_block_number,
      "stake_updated_at_block_number" => validator.stake_updated_at_block_number
    })
  end

  defp prepare_stability_validator(validator) do
    %{
      "address" => Helper.address_with_info(nil, validator.address, validator.address_hash, true),
      "state" => validator.state,
      "blocks_validated_count" => validator.blocks_validated
    }
  end

  defp prepare_blackfort_validator(validator) do
    %{
      "address" => Helper.address_with_info(nil, validator.address, validator.address_hash, true),
      "name" => validator.name,
      "commission" => validator.commission,
      "self_bonded_amount" => validator.self_bonded_amount,
      "delegated_amount" => validator.delegated_amount,
      "slashing_status" => %{
        "slashed" => validator.slashing_status_is_slashed,
        "block_number" => validator.slashing_status_by_block,
        "multiplier" => validator.slashing_status_multiplier
      },
      # todo: Next 3 props should be removed in favour `slashing_status` property with the next release after 8.0.0
      "slashing_status_is_slashed" => validator.slashing_status_is_slashed,
      "slashing_status_by_block" => validator.slashing_status_by_block,
      "slashing_status_multiplier" => validator.slashing_status_multiplier
    }
  end

  @spec prepare_zilliqa_validator(Explorer.Chain.Zilliqa.Staker.t()) :: map()
  defp prepare_zilliqa_validator(validator) do
    %{
      "bls_public_key" => validator.bls_public_key,
      "index" => validator.index,
      "balance" => to_string(validator.balance)
    }
  end
end
