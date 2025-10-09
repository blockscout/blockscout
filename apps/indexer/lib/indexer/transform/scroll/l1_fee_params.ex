defmodule Indexer.Transform.Scroll.L1FeeParams do
  @moduledoc """
    Helper functions for transforming data for Scroll L1 fee parameters
    in realtime block fetcher.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  require Logger

  @doc """
    Takes logs from the realtime fetcher, filters them
    by signatures (L1 Gas Oracle events), and prepares an output for
    `Chain.import` function. It doesn't work if L1 Gas Oracle contract
    address is not configured or the chain type is not :scroll. In this case
    the returned value is an empty list.

    ## Parameters
    - `logs`: A list of log entries to filter for L1 Gas Oracle events.

    ## Returns
    - A list of items ready for database import. The list can be empty.
  """
  @spec parse([map()]) :: [Explorer.Chain.Scroll.L1FeeParam.to_import()]
  def parse(logs)

  if @chain_type == :scroll do
    def parse(logs) do
      prev_metadata = Logger.metadata()
      Logger.metadata(fetcher: :scroll_l1_fee_params_realtime)

      # credo:disable-for-next-line Credo.Check.Design.AliasUsage
      gas_oracle = Application.get_env(:indexer, Indexer.Fetcher.Scroll.L1FeeParam)[:gas_oracle]

      # credo:disable-for-lines:2 Credo.Check.Design.AliasUsage
      items =
        if Indexer.Helper.address_correct?(gas_oracle) do
          gas_oracle = String.downcase(gas_oracle)

          logs
          |> Enum.filter(&fee_param_update_event?(&1, gas_oracle))
          |> Enum.map(fn log ->
            Logger.info("Event for parameter update found.")
            # credo:disable-for-next-line Credo.Check.Design.AliasUsage
            Indexer.Fetcher.Scroll.L1FeeParam.event_to_param(
              log.first_topic,
              log.data,
              log.block_number,
              log.transaction_index
            )
          end)
        else
          Logger.error("L1 Gas Oracle contract address is incorrect. Cannot use #{__MODULE__} for parsing logs.")
          []
        end

      Logger.reset_metadata(prev_metadata)

      items
    end

    defp fee_param_update_event?(log, gas_oracle) do
      # credo:disable-for-lines:3 Credo.Check.Design.AliasUsage
      !is_nil(log.first_topic) &&
        String.downcase(log.first_topic) in Indexer.Fetcher.Scroll.L1FeeParam.event_signatures() &&
        String.downcase(Indexer.Helper.address_hash_to_string(log.address_hash)) == gas_oracle
    end
  else
    def parse(_logs), do: []
  end
end
