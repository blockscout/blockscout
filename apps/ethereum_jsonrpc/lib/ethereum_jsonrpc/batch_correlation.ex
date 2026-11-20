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
  a whole (no matched reply and fewer replies than requests, all of them
  errors, e.g. it was rate limited) isn't multiplied into separate requests.

  ## Parameters
  - `id_to_params`: map of request id to request params
  - `requests_fun`: builds the requests of a batch from such a map
  - `json_rpc_named_arguments`: the JSON-RPC connection configuration

  ## Returns
  - `{:ok, correlation, refetch_result}`: `refetch_result` is the result of the
    separate requests. When one of them fails, the replies received so far are
    still returned with the failure, so the caller can check them for errors
    first, and the failed request and the ones not sent after it are returned
    as `unmatched`. The uncorrelated replies of the batch are returned as long
    as a request is left without a reply.
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
  that cannot be attributed are returned without request data (see
  `uncorrelated_errors/1`), so they are never taken for the error of another
  request.

  ## Parameters
  - `responses`: replies matched to a request, as returned by `fetch/3`
  - `uncorrelated`: replies that could not be attributed to a request
  - `annotate_fun`: converts an error reply (`%{id: id, error: error}`) matched
    to a request into the error to return. It returns the error itself, not an
    `{:error, reason}` tuple.

  ## Returns
  - `:ok` if there are no error replies
  - `{:error, errors}` otherwise: the annotated errors of the matched replies,
    followed by the errors of the uncorrelated ones
  """
  @spec check_errors([map()], [map()], (map() -> any())) :: :ok | {:error, [any()]}
  def check_errors(responses, uncorrelated, annotate_fun) do
    attributed_errors = for %{error: _} = response <- responses, do: annotate_fun.(response)

    case attributed_errors ++ uncorrelated_errors(uncorrelated) do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  # keys of the error data the indexer selects the block to refetch by
  @block_selectors ["blockNumber", :block_number]

  @doc """
  Returns the errors of the replies that could not be attributed to a request.

  It is not known which request such an error belongs to, so the block number
  that a node may put into the error `data` is removed: the callers select the
  block to refetch by the block number of an error, and it must only come from
  the request the error is attributed to. The rest of the error is kept.

  ## Parameters
  - `uncorrelated`: replies that could not be attributed to a request

  ## Returns
  - the errors of the error replies, in the order of the replies; replies
    without an error are skipped
  """
  @spec uncorrelated_errors([map()]) :: [any()]
  def uncorrelated_errors(uncorrelated) do
    for %{error: error} <- uncorrelated, do: drop_block_selectors(error)
  end

  defp drop_block_selectors(%{data: data} = error) when is_map(data),
    do: %{error | data: Map.drop(data, @block_selectors)}

  defp drop_block_selectors(error), do: error

  @doc """
  Checks that no request is left without a reply.

  It is called once the errors are checked: a batch with requested ids left
  without a reply is incomplete, so the caller retries or fails instead of
  treating it as complete.

  ## Parameters
  - `unmatched`: requested ids without a matched reply, as returned by
    `fetch/3` or `correlate_responses/2`
  - `id_to_params`: map of request id to request params. It must be the map the
    `unmatched` ids were derived from.

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

  # No matched reply and fewer replies than requests, all of them errors: the
  # batch, or every chunk the transport split it into, failed as a whole (e.g.
  # it was rate limited) and was answered with a single error, so it isn't
  # multiplied into separate requests. With a reply per request the replies are
  # per-request ones that only lack an id, and a reply with a result is never
  # the reply of a rejected batch.
  defp refetch_unmatched?({[], uncorrelated, unmatched}, _id_to_params)
       when length(uncorrelated) < length(unmatched),
       do: not Enum.all?(uncorrelated, &match?(%{error: _}, &1))

  defp refetch_unmatched?(_correlation, _id_to_params), do: true

  # The uncorrelated replies of the batch are replaced by the replies to the
  # separate requests, which are attributable. They are kept, still not
  # attributed to a request, when a request is left without a reply: they are
  # the only replies left for it.
  defp refetch_unmatched(
         {responses, batch_uncorrelated, unmatched},
         id_to_params,
         requests_fun,
         json_rpc_named_arguments
       ) do
    request_separately = &fetch(Map.take(id_to_params, [&1]), requests_fun, json_rpc_named_arguments)

    case refetch_each(unmatched, {responses, [], []}, request_separately) do
      {{_responses, _uncorrelated, []} = correlation, refetch_result} ->
        {:ok, correlation, refetch_result}

      {{responses, uncorrelated, unmatched}, refetch_result} ->
        {:ok, {responses, uncorrelated ++ batch_uncorrelated, unmatched}, refetch_result}
    end
  end

  defp refetch_each([], correlation, _request_separately), do: {correlation, :ok}

  # The separate requests stop at the first one that fails: it and the requests
  # that weren't sent after it stay unmatched.
  defp refetch_each([id | rest], {responses_acc, uncorrelated_acc, unmatched_acc}, request_separately) do
    case request_separately.(id) do
      {:ok, {responses, uncorrelated, unmatched}, :ok} ->
        refetch_each(
          rest,
          {responses_acc ++ responses, uncorrelated_acc ++ uncorrelated, unmatched_acc ++ unmatched},
          request_separately
        )

      {:error, _reason} = error ->
        {{responses_acc, uncorrelated_acc, unmatched_acc ++ [id | rest]}, error}
    end
  end
end
