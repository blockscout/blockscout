defmodule Explorer.Chain.Import.Runner.Helper do
  @moduledoc """
  Provides utility functions for the chain import runners.
  """

  @doc """
  Executes the import function if the configured chain type matches the
  specified `chain_type`.
  """
  @spec chain_type_dependent_import(
          Ecto.Multi.t(),
          chain_type :: atom(),
          (Ecto.Multi.t() -> Ecto.Multi.t())
        ) :: Ecto.Multi.t()
  def chain_type_dependent_import(multi, chain_type, multi_run) do
    if Application.get_env(:explorer, :chain_type) == chain_type do
      multi_run.(multi)
    else
      multi
    end
  end
end
