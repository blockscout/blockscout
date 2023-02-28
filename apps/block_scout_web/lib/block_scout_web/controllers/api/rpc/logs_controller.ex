defmodule BlockScoutWeb.API.RPC.LogsController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Etherscan}

  def getlogs(conn, params) do
    with {:required_params, {:ok, fetched_params}} <- fetch_required_params(params) |> IO.inspect(label: "fetched_params"),
         {:format, {:ok, validated_params}} <- to_valid_format(fetched_params) |> IO.inspect(label: "validated_params"),
         {:ok, logs} <- list_logs(validated_params) do
      render(conn, :getlogs, %{logs: logs})
    else
      {:required_params, {:error, missing_params}} ->
        error = "Required query parameters missing: #{Enum.join(missing_params, ", ")}"
        render(conn, :error, error: error)

      {:format, {:error, param}} ->
        render(conn, :error, error: "Invalid #{param} format")

      {:error, :not_found} ->
        render(conn, :error, error: "No logs found", data: [])
    end
  end

  # Interpretation of `@maybe_required_params`:
  #
  # If a pair of `topic{x}` params is provided, then the corresponding
  # `topic{x}_{x}_opr` param is required.
  #
  # For example, if "topic0" and "topic1" are provided, then "topic0_1_opr" is
  # required.
  #
  @maybe_required_params %{
    ["topic0", "topic1"] => "topic0_1_opr",
    ["topic0", "topic2"] => "topic0_2_opr",
    ["topic0", "topic3"] => "topic0_3_opr",
    ["topic1", "topic2"] => "topic1_2_opr",
    ["topic1", "topic3"] => "topic1_3_opr",
    ["topic2", "topic3"] => "topic2_3_opr"
  }

  @required_params %{
    # all_of: all of these parameters are required
    all_of: ["fromBlock", "toBlock"],
    # one_of: at least one of these parameters is required
    one_of: ["address", "topic0", "topic1", "topic2", "topic3"]
  }

  @doc """
  Fetches required params. Returns error tuple if required params are missing.

  """
  @spec fetch_required_params(map()) :: {:required_params, {:ok, map()} | {:error, [String.t(), ...]}}
  def fetch_required_params(params) do
    all_of_params = fetch_required_params(params, :all_of)
    one_of_params = fetch_required_params(params, :one_of)
    maybe_params = fetch_required_params(params, :maybe)

    result =
      case {all_of_params, one_of_params, maybe_params} do
        {{:error, missing_params}, {:error, _}, _} ->
          {:error, Enum.concat(missing_params, ["address and/or topic{x}"])}

        {{:error, missing_params}, {:ok, _}, _} ->
          {:error, missing_params}

        {{:ok, _}, {:error, _}, _} ->
          {:error, ["address and/or topic{x}"]}

        {{:ok, _}, {:ok, _}, {:error, missing_params}} ->
          {:error, missing_params}

        {{:ok, all_of_params}, {:ok, one_of_params}, {:ok, maybe_params}} ->
          fetched_params =
            all_of_params
            |> Map.merge(one_of_params)
            |> Map.merge(maybe_params)

          {:ok, fetched_params}
      end

    {:required_params, result}
  end

  @doc """
  Prepares params for processing. Returns error tuple if invalid format is
  found.

  """
  @spec to_valid_format(map()) :: {:format, {:ok, map()} | {:error, String.t()}}
  def to_valid_format(params) do
    result =
      with {:ok, from_block} <- to_block_number(params, "fromBlock"),
           {:ok, to_block} <- to_block_number(params, "toBlock"),
           {:ok, address_hash} <- to_address_hash(params["address"]),
           :ok <- validate_topic_operators(params) do
        validated_params = %{
          from_block: from_block,
          to_block: to_block,
          address_hash: address_hash,
          first_topic: params["topic0"],
          second_topic: params["topic1"],
          third_topic: params["topic2"],
          fourth_topic: params["topic3"],
          topic0_1_opr: params["topic0_1_opr"],
          topic0_2_opr: params["topic0_2_opr"],
          topic0_3_opr: params["topic0_3_opr"],
          topic1_2_opr: params["topic1_2_opr"],
          topic1_3_opr: params["topic1_3_opr"],
          topic2_3_opr: params["topic2_3_opr"]
        }

        {:ok, validated_params}
      else
        {:error, param_key} ->
          {:error, param_key}
      end

    {:format, result}
  end

  defp fetch_required_params(params, :all_of) do
    fetched_params = Map.take(params, @required_params.all_of)

    if all_of_required_keys_found?(fetched_params) do
      {:ok, fetched_params}
    else
      missing_params = get_missing_required_params(fetched_params, :all_of)
      {:error, missing_params}
    end
  end

  defp fetch_required_params(params, :one_of) do
    fetched_params = Map.take(params, @required_params.one_of)
    found_keys = Map.keys(fetched_params)

    if length(found_keys) > 0 do
      {:ok, fetched_params}
    else
      {:error, @required_params.one_of}
    end
  end

  defp fetch_required_params(params, :maybe) do
    case get_missing_required_params(params, :maybe) do
      [] ->
        keys_to_fetch = Map.values(@maybe_required_params)
        {:ok, Map.take(params, keys_to_fetch)}

      missing_params ->
        {:error, Enum.reverse(missing_params)}
    end
  end

  defp all_of_required_keys_found?(fetched_params) do
    Enum.all?(@required_params.all_of, &Map.has_key?(fetched_params, &1))
  end

  defp get_missing_required_params(fetched_params, :all_of) do
    fetched_keys = fetched_params |> Map.keys() |> MapSet.new()

    @required_params.all_of
    |> MapSet.new()
    |> MapSet.difference(fetched_keys)
    |> MapSet.to_list()
  end

  defp get_missing_required_params(fetched_params, :maybe) do
    Enum.reduce(@maybe_required_params, [], fn {[key1, key2], expectation}, missing_params ->
      has_key1? = Map.has_key?(fetched_params, key1)
      has_key2? = Map.has_key?(fetched_params, key2)
      has_expectation? = Map.has_key?(fetched_params, expectation)

      case {has_key1?, has_key2?, has_expectation?} do
        {true, true, false} ->
          [expectation | missing_params]

        _ ->
          missing_params
      end
    end)
  end

  defp to_block_number(params, param_key) do
    case params[param_key] do
      "latest" ->
        Chain.max_consensus_block_number()

      _ ->
        to_integer(params, param_key)
    end
  end

  defp to_integer(params, param_key) do
    case Integer.parse(params[param_key]) do
      {integer, ""} ->
        {:ok, integer}

      _ ->
        {:error, param_key}
    end
  end

  defp to_address_hash(nil), do: {:ok, nil}

  defp to_address_hash(address_hash_string) do
    case Chain.string_to_address_hash(address_hash_string) do
      :error ->
        {:error, "address"}

      {:ok, address_hash} ->
        {:ok, address_hash}
    end
  end

  defp validate_topic_operators(params) do
    topic_operator_keys = Map.values(@maybe_required_params)

    first_invalid_topic_operator =
      Enum.find(topic_operator_keys, fn topic_operator ->
        params[topic_operator] not in ["and", "or", nil]
      end)

    case first_invalid_topic_operator do
      nil ->
        :ok

      invalid_topic_operator ->
        {:error, invalid_topic_operator}
    end
  end

  defp list_logs(filter) do
    case Etherscan.list_logs(filter) do
      [] -> {:error, :not_found}
      logs -> {:ok, logs}
    end
  end
end
