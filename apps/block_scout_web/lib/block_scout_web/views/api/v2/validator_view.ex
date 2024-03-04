defmodule BlockScoutWeb.API.V2.ValidatorView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper

  def render("stability_validators.json", %{validators: validators, next_page_params: next_page_params}) do
    %{"items" => Enum.map(validators, &prepare_validator(&1)), "next_page_params" => next_page_params}
  end

  defp prepare_validator(validator) do
    %{
      "address" => Helper.address_with_info(nil, validator.address, validator.address_hash, true),
      "state" => validator.state,
      "blocks_validated_count" => validator.blocks_validated
    }
  end
end
