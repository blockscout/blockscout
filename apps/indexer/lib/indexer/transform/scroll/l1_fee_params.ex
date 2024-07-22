defmodule Indexer.Transform.Scroll.L1FeeParams do
  @moduledoc """
    Helper functions for transforming data for Scroll L1 fee parameters.
  """

  require Logger

  alias Indexer.Fetcher.Scroll.L1FeeParam, as: ScrollL1FeeParam
  alias Indexer.Helper

  @doc """
  Returns a list of params given a list of logs.
  """
  def parse(logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :scroll_l1_fee_params_realtime)

    gas_oracle = Application.get_env(:indexer, ScrollL1FeeParam)[:gas_oracle]

    items =
      with false <- Application.get_env(:explorer, :chain_type) != :scroll,
           true <- Helper.address_correct?(gas_oracle) do
        gas_oracle = String.downcase(gas_oracle)

        logs
        |> Enum.filter(fn log ->
          !is_nil(log.first_topic) && String.downcase(log.first_topic) in ScrollL1FeeParam.event_signatures() &&
            String.downcase(Helper.address_hash_to_string(log.address_hash)) == gas_oracle
        end)
        |> Enum.map(fn log ->
          Logger.info("Event for parameter update found.")
          ScrollL1FeeParam.event_to_param(log.first_topic, log.data, log.block_number, log.transaction_index)
        end)
      else
        true ->
          []

        false ->
          Logger.error("L1 Gas Oracle contract address is incorrect. Cannot use #{__MODULE__} for parsing logs.")
          []
      end

    Logger.reset_metadata(prev_metadata)

    items
  end
end
