defmodule BlockScoutWeb.API.V2.ValidatorView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper

  def render("stability_validators.json", %{validators: validators, next_page_params: next_page_params}) do
    %{"items" => Enum.map(validators, &prepare_stability_validator(&1)), "next_page_params" => next_page_params}
  end

  def render("blackfort_validators.json", %{validators: validators, next_page_params: next_page_params}) do
    %{"items" => Enum.map(validators, &prepare_blackfort_validator(&1)), "next_page_params" => next_page_params}
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
      "slashing_status_is_slashed" => validator.slashing_status_is_slashed,
      "slashing_status_by_block" => validator.slashing_status_by_block,
      "slashing_status_multiplier" => validator.slashing_status_multiplier
    }
  end
end
