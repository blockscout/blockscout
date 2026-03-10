defmodule Indexer.Fetcher.RpcErrorHelper do
  @moduledoc """
  Helpers for classifying JSON-RPC errors as retryable or non-retryable.

  Errors from pruned archive nodes (e.g., "missing trie node") will never
  succeed on retry — the historical state is gone. Instead of retrying forever
  and burning resources, callers should skip these entries gracefully.
  """

  @doc """
  Returns `true` if the given error reason indicates a permanently missing
  state that will never become available (pruned node, missing trie node, etc.).
  """
  @spec non_retryable_error?(any()) :: boolean()
  def non_retryable_error?(reason) when is_binary(reason) do
    downcased = String.downcase(reason)

    String.contains?(downcased, "missing trie node") or
      String.contains?(downcased, "required historical state unavailable") or
      String.contains?(downcased, "header not found") or
      String.contains?(downcased, "state is not available") or
      String.contains?(downcased, "block not found") or
      String.contains?(downcased, "unknown block") or
      String.contains?(downcased, "genesis is not traceable")
  end

  def non_retryable_error?(%{message: message}) when is_binary(message) do
    non_retryable_error?(message)
  end

  def non_retryable_error?(%{"message" => message}) when is_binary(message) do
    non_retryable_error?(message)
  end

  def non_retryable_error?({:error, reason}) do
    non_retryable_error?(reason)
  end

  def non_retryable_error?(errors) when is_list(errors) do
    Enum.any?(errors, &non_retryable_error?/1)
  end

  def non_retryable_error?(_), do: false

  @doc """
  Partitions a list of fetched balance/code errors into retryable and
  non-retryable errors.

  Returns `{retryable_errors, non_retryable_errors}`.
  """
  @spec partition_errors([map()]) :: {[map()], [map()]}
  def partition_errors(errors) when is_list(errors) do
    Enum.split_with(errors, fn error ->
      message = error[:message] || error["message"] || ""
      not non_retryable_error?(message)
    end)
  end
end
