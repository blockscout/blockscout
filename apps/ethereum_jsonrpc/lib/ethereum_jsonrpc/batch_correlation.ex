# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.BatchCorrelation do
  @moduledoc """
  Matches the replies of a JSON-RPC batch to its requests and detects the
  requests that are left without a reply.

  The batch transport accepts a reply with fewer entries than requested, so a
  caller that only processes the replies that arrived treats an incomplete
  batch as a complete one. The functions of this module let a caller reject
  such a batch instead.
  """

  import EthereumJSONRPC, only: [json_rpc: 2]

  alias EthereumJSONRPC.Transport

  @typedoc """
  - `responses`: replies matched to a requested id
  - `uncorrelated`: replies that could not be attributed to a request
  - `unmatched`: requested ids without a matched reply
  """
  @type correlation :: {responses :: [map()], uncorrelated :: [map()], unmatched :: [non_neg_integer()]}

  @type id_to_params :: %{non_neg_integer() => any()}

  @doc """
  Sends the batch and matches the replies to the requests.

  The requests of a partially answered batch that are left without a reply are
  sent again, each one separately: a reply to a single request is always
  attributable, even without an id, and the replies that did arrive are kept
  instead of being requested again with the whole batch. A batch that failed as
  a whole (no matched reply and at most one reply, e.g. it was rate limited)
  isn't multiplied into separate requests.

  ## Parameters
  - `id_to_params`: map of request id to request params
  - `requests_fun`: builds the requests of a batch from such a map
  - `json_rpc_named_arguments`: the JSON-RPC connection configuration

  ## Returns
  - `{:ok, correlation, refetch_result}`: `refetch_result` is the result of the
    separate requests. When one of them fails, the replies received so far are
    still returned with the failure, so the caller can check them for errors
    first.
  - `{:error, reason}` if the batch request failed
  """
  @spec fetch(id_to_params(), (id_to_params() -> [Transport.request()]), EthereumJSONRPC.json_rpc_named_arguments()) ::
          {:ok, correlation(), :ok | {:error, any()}} | {:error, any()}
  def fetch(id_to_params, requests_fun, json_rpc_named_arguments) do
    with {:ok, raw_responses} <- id_to_params |> requests_fun.() |> json_rpc(json_rpc_named_arguments) do
      correlation = correlate_responses(raw_responses, id_to_params)

      if refetch_unmatched?(correlation, id_to_params) do
        refetch_unmatched(correlation, id_to_params, requests_fun, json_rpc_named_arguments)
      else
        {:ok, correlation, :ok}
      end
    end
  end

  @doc """
  Matches batch replies to the requested ids.

  Replies are matched by id, not by position, so a complete batch whose replies
  arrive out of order is accepted. Only the first reply with a requested id is
  matched: replies with an id that was not requested, and repeated replies with
  the same id, are left uncorrelated.

  Some endpoints omit the id in error replies. Such a reply is attributed to a
  request only when the batch consists of that single request, as that is the
  only case in which it is certain which request the reply answered: a reply
  without an id in a bigger batch can be an error of a whole chunk of the
  batch. It is left uncorrelated instead of being guessed from the reply order.

  ## Parameters
  - `responses`: raw batch replies
  - `id_to_params`: map of request id to request params that was used to build
    the batch

  ## Returns
  - `{responses, uncorrelated, unmatched}`, where `responses` include the
    attributed reply without an id
  """
  @spec correlate_responses([map()], id_to_params()) :: correlation()
  def correlate_responses(responses, id_to_params) do
    {correlated, uncorrelated, matched_ids} =
      Enum.reduce(responses, {[], [], MapSet.new()}, fn %{id: id} = response, {correlated, uncorrelated, matched_ids} ->
        if Map.has_key?(id_to_params, id) and not MapSet.member?(matched_ids, id) do
          {[response | correlated], uncorrelated, MapSet.put(matched_ids, id)}
        else
          {correlated, [response | uncorrelated], matched_ids}
        end
      end)

    unmatched = id_to_params |> Map.keys() |> Enum.reject(&MapSet.member?(matched_ids, &1))

    case {map_size(id_to_params), unmatched, uncorrelated} do
      {1, [id], [%{id: nil} = response]} -> {[%{response | id: id}], [], []}
      _ -> {Enum.reverse(correlated), Enum.reverse(uncorrelated), unmatched}
    end
  end

  @doc """
  Collects the errors of the replies.

  The error replies attributed to a request are converted with `annotate_fun`,
  which is expected to add the request data to the error. Errors of replies
  that cannot be attributed are returned as they are, without request data, so
  they are never taken for the error of another request.

  ## Returns
  - `:ok` if there are no error replies
  - `{:error, errors}` otherwise
  """
  @spec check_errors([map()], [map()], (map() -> any())) :: :ok | {:error, [any()]}
  def check_errors(responses, uncorrelated, annotate_fun) do
    attributed_errors = for %{error: _} = response <- responses, do: annotate_fun.(response)

    case attributed_errors ++ uncorrelated_errors(uncorrelated) do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  @doc """
  Returns the errors of the replies that could not be attributed to a request.
  """
  @spec uncorrelated_errors([map()]) :: [any()]
  def uncorrelated_errors(uncorrelated) do
    for %{error: error} <- uncorrelated, do: error
  end

  @doc """
  Checks that no request is left without a reply.

  It is called once the errors are checked: a batch with requested ids left
  without a reply is incomplete, so the caller retries or fails instead of
  treating it as complete.

  ## Returns
  - `:ok` if every request got a reply
  - `{:error, {:missing_responses, params}}` with the params of the requests
    left without a reply
  """
  @spec check_no_missing_responses([non_neg_integer()], id_to_params()) ::
          :ok | {:error, {:missing_responses, [any()]}}
  def check_no_missing_responses([], _id_to_params), do: :ok

  def check_no_missing_responses(unmatched, id_to_params),
    do: {:error, {:missing_responses, Enum.map(unmatched, &Map.fetch!(id_to_params, &1))}}

  defp refetch_unmatched?({_responses, _uncorrelated, []}, _id_to_params), do: false

  # a single request can't be narrowed down any further
  defp refetch_unmatched?(_correlation, id_to_params) when map_size(id_to_params) == 1, do: false

  # At most one reply and no matched ones: the batch failed as a whole (e.g. it
  # was rate limited), so it isn't multiplied into separate requests.
  defp refetch_unmatched?({[], uncorrelated, _unmatched}, _id_to_params) when length(uncorrelated) <= 1, do: false

  defp refetch_unmatched?(_correlation, _id_to_params), do: true

  # The uncorrelated replies of the batch are dropped here: the requests they
  # could answer are sent again, and their replies are attributable this time.
  # The separate requests stop at the first one that fails. The uncorrelated
  # replies of the batch are returned in that case, still not attributed to a
  # request: they are the only replies left for the requests that weren't
  # answered separately.
  defp refetch_unmatched(
         {responses, batch_uncorrelated, unmatched},
         id_to_params,
         requests_fun,
         json_rpc_named_arguments
       ) do
    Enum.reduce_while(unmatched, {:ok, {responses, [], []}, :ok}, fn id,
                                                                     {:ok,
                                                                      {responses_acc, uncorrelated_acc, unmatched_acc},
                                                                      :ok} ->
      case fetch(Map.take(id_to_params, [id]), requests_fun, json_rpc_named_arguments) do
        {:ok, {responses, uncorrelated, unmatched}, :ok} ->
          {:cont,
           {:ok, {responses_acc ++ responses, uncorrelated_acc ++ uncorrelated, unmatched_acc ++ unmatched}, :ok}}

        {:error, _reason} = error ->
          {:halt, {:ok, {responses_acc, uncorrelated_acc ++ batch_uncorrelated, unmatched_acc}, error}}
      end
    end)
  end
end
