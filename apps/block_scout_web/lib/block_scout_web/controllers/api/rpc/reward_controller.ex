defmodule BlockScoutWeb.API.RPC.RewardController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.CeloElectionRewards

  def getvoterrewardsforgroup(conn, params) do
    with {:voter_address_param, {:ok, voter_address_param}} <- fetch_address(params, "voterAddress"),
         {:group_address_param, {:ok, group_address_param}} <- fetch_address(params, "groupAddress"),
         {:voter_format, {:ok, voter_address_hash}} <- to_address_hash_list(voter_address_param, :voter_format),
         {:group_format, {:ok, group_address_hash}} <- to_address_hash_list(group_address_param, :group_format),
         rewards <- CeloElectionRewards.get_voter_rewards_for_group(voter_address_hash, group_address_hash) do
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
    end
  end

  def getvoterrewards(conn, params) do
    with {:voter_address_param, {:ok, voter_address_param}} <- fetch_address(params, "voterAddress"),
         {:voter_format, {:ok, voter_hash_list}} <- to_address_hash_list(voter_address_param, :voter_format),
         {:date_param, {:ok, from, _}} <- fetch_date(params["from"]),
         {:date_param, {:ok, to, _}} <- fetch_date(params["to"]),
         rewards <- CeloElectionRewards.get_rewards(voter_hash_list, ["voter"], from, to) do
      render(conn, :getvoterrewards, rewards: rewards)
    else
      {:voter_address_param, :error} ->
        render(conn, :error, error: "Query parameter 'voterAddress' is required")

      {:voter_format, :error} ->
        render(conn, :error, error: "One or more voter addresses are invalid")

      {:date_param, {:error, _}} ->
        render(conn, :error, error: "Please only ISO 8601 formatted dates")
    end
  end

  def getvalidatorrewards(conn, params) do
    with {:validator_address_param, {:ok, validator_address_param}} <- fetch_address(params, "validatorAddress"),
         {:validator_format, {:ok, validator_hash_list}} <-
           to_address_hash_list(validator_address_param, :validator_format),
         {:date_param, {:ok, from, _}} <- fetch_date(params["from"]),
         {:date_param, {:ok, to, _}} <- fetch_date(params["to"]),
         rewards <- CeloElectionRewards.get_rewards(validator_hash_list, ["validator"], from, to) do
      render(conn, :getvalidatorrewards, rewards: rewards)
    else
      {:validator_address_param, :error} ->
        render(conn, :error, error: "Query parameter 'validatorAddress' is required")

      {:validator_format, :error} ->
        render(conn, :error, error: "One or more validator addresses are invalid")

      {:date_param, {:error, _}} ->
        render(conn, :error, error: "Please only ISO 8601 formatted dates")
    end
  end

  def getvalidatorgrouprewards(conn, params) do
    with {:group_address_param, {:ok, group_address_param}} <- fetch_address(params, "groupAddress"),
         {:group_format, {:ok, group_hash_list}} <- to_address_hash_list(group_address_param, :group_format),
         {:date_param, {:ok, from, _}} <- fetch_date(params["from"]),
         {:date_param, {:ok, to, _}} <- fetch_date(params["to"]),
         rewards <- CeloElectionRewards.get_rewards(group_hash_list, ["group"], from, to) do
      render(conn, :getvalidatorgrouprewards, rewards: rewards)
    else
      {:group_address_param, :error} ->
        render(conn, :error, error: "Query parameter 'groupAddress' is required")

      {:group_format, :error} ->
        render(conn, :error, error: "One or more group addresses are invalid")

      {:date_param, {:error, _}} ->
        render(conn, :error, error: "Please only ISO 8601 formatted dates")
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

  defp to_address_hash_list(address_hashes_string, key) do
    uncast_hashes = split_address_input_string(address_hashes_string)

    cast_hashes = Enum.map(uncast_hashes, &Chain.string_to_address_hash/1)

    if Enum.all?(cast_hashes, fn
         {:ok, _} -> true
         _ -> false
       end) do
      {key, {:ok, Enum.map(cast_hashes, fn {:ok, hash} -> hash end)}}
    else
      {key, :error}
    end
  end

  defp split_address_input_string(address_input_string) do
    address_input_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp fetch_date(date) do
    case date do
      nil -> {:date_param, {:ok, nil, nil}}
      date -> {:date_param, DateTime.from_iso8601(date)}
    end
  end
end
