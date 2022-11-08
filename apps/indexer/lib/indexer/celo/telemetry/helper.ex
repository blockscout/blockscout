defmodule Indexer.Celo.Telemetry.Helper do
  @moduledoc "Helper functions for telemetry event processing"

  @doc """
    Filters out changes from the full list of imports to only those that we care about
    This is necessary as Import.all will return a mapping of each Ecto.Multi stage id to count of rows affected
  """
  def filter_imports(changes, _meta) do
    changes
    |> Enum.reduce(%{}, fn import, acc ->
      case take_import(import) do
        {key, count} -> Map.put(acc, key, count)
        nil -> acc
      end
    end)
  end

  defp take_import({:insert_celo_election_rewards_items, count}), do: {:celo_election_rewards, count}
  defp take_import({:insert_celo_params_items, count}), do: {:celo_params, count}
  defp take_import({:insert_celo_signer_items, count}), do: {:celo_signers, count}
  defp take_import({:insert_validator_group_items, count}), do: {:celo_validator_group, count}
  defp take_import({:insert_validator_history_items, count}), do: {:celo_validator_history, count}
  defp take_import({:insert_validator_status_items, count}), do: {:celo_validator_status, count}
  defp take_import({:insert_celo_accounts, count}), do: {:celo_accounts, count}
  defp take_import({:insert_celo_validators, count}), do: {:celo_validators, count}
  defp take_import({:insert_wallets, count}), do: {:celo_wallets, count}
  defp take_import({:insert_celo_voters, count}), do: {:celo_voters, count}
  defp take_import({:insert_account_epoch_items, count}), do: {:celo_account_epoch, count}
  defp take_import({:celo_unlocked, _} = cl), do: cl
  defp take_import({:celo_contract_event, _} = cce), do: cce
  defp take_import({:celo_core_contracts, _} = ccc), do: ccc
  defp take_import({:celo_epoch_rewards, _} = epoch_rewards), do: epoch_rewards

  defp take_import({:tracked_contract_events, count}), do: {:contract_event, count}

  defp take_import({:address_coin_balances_daily, _} = address_coin_balances_daily), do: address_coin_balances_daily
  defp take_import({:address_coin_balances, _} = address_coin_balances), do: address_coin_balances
  defp take_import({:insert_names, count}), do: {:address_names, count}
  defp take_import({:address_token_balances, _} = address_token_balances), do: address_token_balances

  defp take_import({:address_current_token_balances, _} = address_current_token_balances),
    do: address_current_token_balances

  defp take_import({:addresses, _} = addresses), do: addresses
  defp take_import({:transactions, _} = tx), do: tx
  defp take_import({:blocks, _} = blocks), do: blocks
  defp take_import({:token_transfers, _} = tt), do: tt
  defp take_import({:tokens, _} = t), do: t
  defp take_import({:logs, _} = logs), do: logs
  defp take_import({:internal_transactions, _} = itx), do: itx

  defp take_import(_), do: nil

  def transform_db_call(_measurements, %{func: function_name}), do: %{function_name => 1}
end
