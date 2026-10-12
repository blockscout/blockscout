# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.Actions do
  @moduledoc """
  What happens once transfers have been identified as poisoning attacks:
  the positive verdicts go to the configured
  `Explorer.Chain.TokenTransfer.PoisoningAttack.Reporter`, unless the
  operator turned the actions off.
  """

  require Logger

  alias Explorer.Chain.TokenTransfer.PoisoningAttack.{Config, Result}

  @doc """
  Reports the attacks among `results`. A failing reporter is logged and
  never raises: the verdicts are already recorded, and re-scoring them would
  not help.
  """
  @spec apply([Result.t()], Config.t()) :: :ok
  def apply(results, %Config{actions_enabled: true, reporter: reporter} = config) when is_atom(reporter) do
    case Enum.filter(results, &Result.attack?(&1, config)) do
      [] -> :ok
      attacks -> report(reporter, attacks)
    end
  end

  def apply(_results, _config), do: :ok

  defp report(reporter, attacks) do
    reporter.report(attacks)
  rescue
    error ->
      Logger.error(fn ->
        [
          "Failed to report poisoning attacks through ",
          inspect(reporter),
          ": ",
          Exception.format(:error, error, __STACKTRACE__)
        ]
      end)

      :ok
  end
end
