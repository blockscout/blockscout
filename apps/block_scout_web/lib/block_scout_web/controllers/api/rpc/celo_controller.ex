defmodule BlockScoutWeb.API.RPC.CeloController do
  use BlockScoutWeb, :controller
  alias Explorer.Helper
  alias Explorer.Chain.Celo.{ElectionReward, Epoch}

  @max_safe_epoch_number 32_768

  def getepoch(conn, params) do
    options = [
      necessity_by_association: %{
        :distribution => :optional,
        :start_processing_block => :optional,
        :end_processing_block => :optional
      },
      api?: true
    ]

    with {:param, {:ok, epoch_number}} <-
           {:param, Map.fetch(params, "epochNumber")},
         {:format, {:ok, epoch_number}} <-
           {:format, Helper.safe_parse_non_negative_integer(epoch_number, @max_safe_epoch_number)},
         {:epoch, {:ok, epoch}} <- {:epoch, Epoch.from_number(epoch_number, options)} do
      aggregated_rewards = ElectionReward.epoch_number_to_rewards_aggregated_by_type(epoch.number, options)

      conn
      |> render(:celo_epoch, epoch: epoch, aggregated_rewards: aggregated_rewards)
    else
      {:param, :error} ->
        render(conn, :error, error: "Query parameter 'epochNumber' is required")

      {:format, {:error, type}} ->
        error =
          case type do
            :negative_integer -> "Epoch number cannot be negative"
            :too_big_integer -> "Epoch number is too big"
            :invalid_integer -> "Invalid epoch number"
          end

        render(conn, :error, error: error)

      {:epoch, {:error, :not_found}} ->
        render(conn, :error, error: "No epoch found")
    end
  end
end
