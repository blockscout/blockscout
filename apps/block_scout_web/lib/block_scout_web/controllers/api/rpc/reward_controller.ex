defmodule BlockScoutWeb.API.RPC.RewardController do
  use BlockScoutWeb, :controller

  alias Explorer.Celo.{ValidatorGroupRewards, ValidatorRewards, VoterRewards, VoterRewardsForGroup}
  alias Explorer.Chain

  def getvoterrewardsforgroup(conn, params) do
    with {:voter_address_param, {:ok, voter_address_param}} <- fetch_address(params, "voterAddress"),
         {:group_address_param, {:ok, group_address_param}} <- fetch_address(params, "groupAddress"),
         {:voter_format, {:ok, voter_address_hash}} <- to_address_hash(voter_address_param, "voterAddress"),
         {:group_format, {:ok, group_address_hash}} <- to_address_hash(group_address_param, "groupAddress"),
         {:ok, rewards} <- VoterRewardsForGroup.calculate(voter_address_hash, group_address_hash) do
      render(conn, :getvoterrewardsforgroup, rewards: rewards)
    else
      {:voter_address_param, :error} ->
        render(conn, :error, error: "Query parameter 'voterAddress' is required")

      {:group_address_param, :error} ->
        render(conn, :error, error: "Query parameter 'groupAddress' is required")

      {:voter_format, :error} ->
        render(conn, :error, error: "Invalid voter address hash")

      {:group_format, :error} ->
        render(conn, :error, error: "Invalid group address hash")

      {:error, :not_found} ->
        render(conn, :error, error: "Voter or group address does not exist")
    end
  end

  def getvoterrewards(conn, params) do
    with {:voter_address_param, {:ok, voter_address_param}} <- fetch_address(params, "voterAddress"),
         {:voter_format, {:ok, voter_address_hash}} <- to_address_hash(voter_address_param, "voterAddress"),
         {:date_param, {:ok, from, _}} <- fetch_date(params["from"]),
         {:date_param, {:ok, to, _}} <- fetch_date(params["to"]),
         {:ok, rewards} <- VoterRewards.calculate(voter_address_hash, from, to) do
      render(conn, :getvoterrewards, rewards: rewards)
    else
      {:voter_address_param, :error} ->
        render(conn, :error, error: "Query parameter 'voterAddress' is required")

      {:voter_format, :error} ->
        render(conn, :error, error: "Invalid voter address hash")

      {:date_param, {:error, _}} ->
        render(conn, :error, error: "Please only ISO 8601 formatted dates")

      {:error, :not_found} ->
        render(conn, :error, error: "Voter address does not exist")
    end
  end

  def getvalidatorrewards(conn, params) do
    with {:validator_address_param, {:ok, validator_address_param}} <- fetch_address(params, "validatorAddress"),
         {:validator_format, {:ok, validator_address_hash}} <-
           to_address_hash(validator_address_param, "validatorAddress"),
         {:date_param, {:ok, from, _}} <- fetch_date(params["from"]),
         {:date_param, {:ok, to, _}} <- fetch_date(params["to"]),
         {:ok, rewards} <- ValidatorRewards.calculate(validator_address_hash, from, to) do
      render(conn, :getvalidatorrewards, rewards: rewards)
    else
      {:validator_address_param, :error} ->
        render(conn, :error, error: "Query parameter 'validatorAddress' is required")

      {:validator_format, :error} ->
        render(conn, :error, error: "Invalid validator address hash")

      {:date_param, {:error, _}} ->
        render(conn, :error, error: "Please only ISO 8601 formatted dates")

      {:error, :not_found} ->
        render(conn, :error, error: "Validator address does not exist")
    end
  end

  def getvalidatorgrouprewards(conn, params) do
    with {:group_address_param, {:ok, group_address_param}} <- fetch_address(params, "groupAddress"),
         {:group_format, {:ok, group_address_hash}} <- to_address_hash(group_address_param, "groupAddress"),
         {:date_param, {:ok, from, _}} <- fetch_date(params["from"]),
         {:date_param, {:ok, to, _}} <- fetch_date(params["to"]),
         {:ok, rewards} <- ValidatorGroupRewards.calculate(group_address_hash, from, to) do
      render(conn, :getvalidatorgrouprewards, rewards: rewards)
    else
      {:group_address_param, :error} ->
        render(conn, :error, error: "Query parameter 'groupAddress' is required")

      {:group_format, :error} ->
        render(conn, :error, error: "Invalid group address hash")

      {:date_param, {:error, _}} ->
        render(conn, :error, error: "Please only ISO 8601 formatted dates")

      {:error, :not_found} ->
        render(conn, :error, error: "Group address does not exist")
    end
  end

  defp fetch_address(params, key) when key == "voterAddress" do
    {:voter_address_param, Map.fetch(params, key)}
  end

  defp fetch_address(params, key) when key == "groupAddress" do
    {:group_address_param, Map.fetch(params, key)}
  end

  defp fetch_address(params, key) when key == "validatorAddress" do
    {:validator_address_param, Map.fetch(params, key)}
  end

  defp fetch_date(date) do
    case date do
      nil -> {:date_param, {:ok, nil, nil}}
      date -> {:date_param, DateTime.from_iso8601(date)}
    end
  end

  defp to_address_hash(address_hash_string, key) when key == "voterAddress" do
    {:voter_format, Chain.string_to_address_hash(address_hash_string)}
  end

  defp to_address_hash(address_hash_string, key) when key == "groupAddress" do
    {:group_format, Chain.string_to_address_hash(address_hash_string)}
  end

  defp to_address_hash(address_hash_string, key) when key == "validatorAddress" do
    {:validator_format, Chain.string_to_address_hash(address_hash_string)}
  end
end
