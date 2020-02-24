defmodule BlockScoutWeb.Resolvers.CeloParameters do
  @moduledoc false

  alias Explorer.Chain

  def get_by(_, _, _) do
    with {:ok, result} <- Chain.get_celo_parameters(),
         {:ok, locked} <- get_param(result, "totalLockedGold"),
         {:ok, validators} <- get_param(result, "numRegisteredValidators"),
         {:ok, min_validators} <- get_param(result, "minElectableValidators"),
         {:ok, max_validators} <- get_param(result, "maxElectableValidators") do
      {:ok,
       %{
         total_locked_gold: locked,
         min_electable_validators: min_validators.value,
         max_electable_validators: max_validators.value,
         num_registered_validators: validators.value
       }}
    else
      _ -> {:error, "Celo network parameters not found???"}
    end
  end

  defp get_param(lst, name) do
    case Enum.find(lst, fn el -> el.name == name end) do
      nil -> {:error, :not_found}
      elem -> {:ok, elem.number_value}
    end
  end
end
