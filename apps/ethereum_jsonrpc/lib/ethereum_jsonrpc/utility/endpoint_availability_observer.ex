defmodule EthereumJSONRPC.Utility.EndpointAvailabilityObserver do
  @moduledoc """
  Monitors and manages the availability of JSON-RPC endpoints.

  This module maintains the health status of various endpoint types (WebSocket, HTTP,
  trace, eth_call) by tracking error occurrences and managing endpoint availability.
  It can be used in the scenarios where automatic fallback to alternative URLs is needed
  when primary endpoints become unavailable.

  ## State Structure

  The GenServer maintains two main state components:
  - `error_counts`: Maps endpoint URLs to their error counts by type

      %{
        "url" => %{
          url_type => %{count: integer(), last_occasion: timestamp}
        }
      }

  - `unavailable_endpoints`: Groups unavailable URLs by their type

      %{
        ws: [String.t()],
        trace: [String.t()],
        http: [String.t()],
        eth_call: [String.t()]
      }

  ## Usage Scenarios

  ### Error Tracking and Availability Management

      # Track errors for an endpoint
      EndpointAvailabilityObserver.inc_error_count(url, json_rpc_args, :http)
      # After reaching maximum error threshold, endpoint becomes unavailable
      # Monitoring starts via EndpointAvailabilityChecker

  ### Fallback URL Management

      # Replace single unavailable URL
      available_url = EndpointAvailabilityObserver.maybe_replace_url(
        primary_url,
        fallback_url,
        :http
      )

      # Replace list of unavailable URLs
      available_urls = EndpointAvailabilityObserver.maybe_replace_urls(
        primary_urls,
        fallback_urls,
        :http
      )

  ### Recovery Handling
  When an unavailable endpoint recovers:
  1. `EthereumJSONRPC.Utility.EndpointAvailabilityChecker` detects successful connection
  2. Calls `enable_endpoint/3` to mark the endpoint as available
  3. Endpoint returns to the available pool
  4. Logging indicates availability status change

  The module automatically cleans up error records for URLs, maintaining only URLs
  for which errors occurred within the specified window.
  """

  use GenServer

  require Logger

  alias EthereumJSONRPC.Utility.{CommonHelper, EndpointAvailabilityChecker}

  @max_error_count 3
  @window_duration 3
  @cleaning_interval :timer.seconds(1)

  @type url_type :: :ws | :trace | :http | :eth_call

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    schedule_next_cleaning()

    {:ok, %{error_counts: %{}, unavailable_endpoints: %{ws: [], trace: [], http: [], eth_call: []}}}
  end

  @doc """
    Increments the error count for an endpoint URL and marks it as unavailable if the
    error threshold is exceeded.

    ## Parameters
    - `url`: The endpoint URL to track errors for
    - `json_rpc_named_arguments`: JSON-RPC configuration for the endpoint
    - `url_type`: Type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)

    ## Returns
    - `:ok`
  """
  @spec inc_error_count(String.t(), EthereumJSONRPC.json_rpc_named_arguments(), url_type()) :: :ok
  def inc_error_count(url, json_rpc_named_arguments, url_type) do
    GenServer.cast(__MODULE__, {:inc_error_count, url, json_rpc_named_arguments, url_type})
  end

  @doc """
    Checks if the given endpoint URL is not marked as unavailable

    ## Parameters
    - `url`: The endpoint URL to check
    - `url_type`: The type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)

    ## Returns
    - `:ok` if the endpoint is available
    - `:unavailable` if the endpoint is marked as unavailable
  """
  @spec check_endpoint(String.t(), url_type()) :: :ok | :unavailable
  def check_endpoint(url, url_type) do
    GenServer.call(__MODULE__, {:check_endpoint, url, url_type})
  end

  @doc """
    Filters a list of given URLs, removing those that are marked as unavailable.

    ## Parameters
    - `urls`: List of URLs to filter
    - `url_type`: Type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)

    ## Returns
    - List of URLs that are not marked as unavailable
  """
  @spec filter_unavailable_urls([String.t()], url_type()) :: [String.t()]
  def filter_unavailable_urls(urls, url_type) do
    GenServer.call(__MODULE__, {:filter_unavailable_urls, urls, url_type})
  end

  @doc """
    Checks if the given endpoint is marked as unavailable and if it is, replaces it with a fallback URL if provided.

    ## Parameters
    - `url`: The original endpoint URL to check
    - `replace_url`: The fallback URL to use if the original is unavailable
    - `url_type`: The type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)

    ## Returns
    - The original `url` if it is available
    - The `replace_url` if the original URL is unavailable and `replace_url` is provided
    - The original `url` if it is unavailable and no `replace_url` is provided
  """
  @spec maybe_replace_url(String.t(), String.t() | nil, url_type()) :: String.t()
  def maybe_replace_url(url, replace_url, url_type) do
    case check_endpoint(url, url_type) do
      :ok -> url
      :unavailable -> replace_url || url
    end
  end

  @doc """
    Checks if all URLs in the given list are marked as unavailable and if they are, replaces them with fallback URLs.

    ## Parameters
    - `urls`: List of original URLs to check
    - `replace_urls`: List of fallback URLs to use if all original URLs are unavailable
    - `url_type`: Type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)

    ## Returns
    - Available URLs from the original list if any exist
    - The `replace_urls` if all original URLs are unavailable and `replace_urls` is provided
    - The original `urls` if all are unavailable and no `replace_urls` is provided
    - Empty list if both `urls` and `replace_urls` are nil
  """
  @spec maybe_replace_urls([String.t()] | nil, [String.t()] | nil, url_type()) :: [String.t()]
  def maybe_replace_urls(urls, replace_urls, url_type) do
    case filter_unavailable_urls(urls, url_type) do
      [] -> replace_urls || urls || []
      available_urls -> available_urls
    end
  end

  @doc """
    Removes the given URL from the list of unavailable endpoints.

    ## Parameters
    - `url`: The endpoint URL to mark as available
    - `url_type`: Type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)
    - `json_rpc_named_arguments`: JSON-RPC configuration for the endpoint

    ## Returns
    - `:ok`
  """
  @spec enable_endpoint(String.t(), url_type(), EthereumJSONRPC.json_rpc_named_arguments()) :: :ok
  def enable_endpoint(url, url_type, json_rpc_named_arguments) do
    GenServer.cast(__MODULE__, {:enable_endpoint, url, url_type, json_rpc_named_arguments})
  end

  # Checks if the given endpoint URL is not marked as unavailable for the specified
  # URL type.
  #
  # ## Parameters
  # - `url`: The endpoint URL to check
  # - `url_type`: The type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)
  # - `state`: The current state containing unavailable endpoints
  #
  # ## Returns
  # - `:ok` if the endpoint is available
  # - `:unavailable` if the endpoint is marked as unavailable
  def handle_call({:check_endpoint, url, url_type}, _from, %{unavailable_endpoints: unavailable_endpoints} = state) do
    result = if url in unavailable_endpoints[url_type], do: :unavailable, else: :ok

    {:reply, result, state}
  end

  # Filters a list of given URLs, removing those that are marked as unavailable for
  # the specified URL type.
  #
  # ## Parameters
  # - `urls`: List of URLs to filter
  # - `url_type`: The type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)
  # - `state`: The current state containing unavailable endpoints
  #
  # ## Returns
  # - `{:reply, [String.t()], state}` List of available URLs
  def handle_call(
        {:filter_unavailable_urls, urls, url_type},
        _from,
        %{unavailable_endpoints: unavailable_endpoints} = state
      ) do
    {:reply, do_filter_unavailable_urls(urls, unavailable_endpoints[url_type]), state}
  end

  # Handles error count increments for endpoint URLs.
  #
  # Increments the error count for a URL unless it is marked as an API endpoint. API
  # endpoints are not monitored for errors.
  #
  # ## Parameters
  # - `url`: The endpoint URL to track errors for
  # - `json_rpc_named_arguments`: JSON-RPC configuration for the endpoint
  # - `url_type`: Type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)
  # - `state`: Current state containing error counts and unavailable endpoints
  #
  # ## Returns
  # - `{:noreply, new_state}` with updated error counts
  def handle_cast({:inc_error_count, url, json_rpc_named_arguments, url_type}, state) do
    new_state =
      if json_rpc_named_arguments[:api?],
        do: state,
        else: do_increase_error_counts(url, json_rpc_named_arguments, url_type, state)

    {:noreply, new_state}
  end

  # Removes the given URL from the list of unavailable endpoints.
  #
  # ## Parameters
  # - `url`: The endpoint URL to enable
  # - `url_type`: The type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)
  # - `json_rpc_named_arguments`: JSON-RPC configuration for the endpoint
  # - `state`: Current state containing unavailable endpoints
  #
  # ## Returns
  # - `{:noreply, new_state}` with updated unavailable endpoints list
  def handle_cast(
        {:enable_endpoint, url, url_type, json_rpc_named_arguments},
        %{unavailable_endpoints: unavailable_endpoints} = state
      ) do
    log_url_available(url, url_type, unavailable_endpoints[url_type], json_rpc_named_arguments)

    {:noreply,
     %{state | unavailable_endpoints: %{unavailable_endpoints | url_type => unavailable_endpoints[url_type] -- [url]}}}
  end

  # For each URL and URL type combination, checks if the last error timestamp is
  # within the window duration (an error happened recently). If not, removes those
  # error records.
  #
  # ## Parameters
  # - `state`: Current state containing error counts by URL and URL type
  #
  # ## Returns
  # - `{:noreply, new_state}` with outdated error records removed
  def handle_info(:clear_old_records, %{error_counts: error_counts} = state) do
    new_error_counts = Enum.reduce(error_counts, %{}, &do_clear_old_records/2)

    schedule_next_cleaning()

    {:noreply, %{state | error_counts: new_error_counts}}
  end

  # For the given url cleans up the records of every url type for which the last
  # error happened too long ago (based on `@window_duration`).
  #
  # It is assumed that this function is called in reducer context, so it accumulates
  # urls for which errors happened recently.
  #
  # ## Parameters
  # - `{url, counts_by_types}`: Tuple of URL and its error counts by type. It is
  #   expected that `counts_by_types` is a map with keys as url types and values
  #   as maps with `:last_occasion` key which is a timestamp of the last error
  #   occurrence.
  # - `acc`: Accumulator map for storing current error records
  #
  # ## Returns
  # - Updated map of error records, excluding expired ones
  @spec do_clear_old_records({String.t(), %{url_type() => %{last_occasion: non_neg_integer()}}}, map()) :: map()
  defp do_clear_old_records({url, counts_by_types}, acc) do
    counts_by_types
    |> Enum.reduce(%{}, fn {type, %{last_occasion: last_occasion} = record}, acc ->
      if now() - last_occasion > @window_duration, do: acc, else: Map.put(acc, type, record)
    end)
    |> case do
      empty_map when empty_map == %{} -> acc
      non_empty_map -> Map.put(acc, url, non_empty_map)
    end
  end

  # Filters out unavailable URLs from the provided list.
  #
  # ## Parameters
  # - `urls`: List of URLs to filter, can be nil
  # - `unavailable_urls`: List of URLs marked as unavailable
  #
  # ## Returns
  # - List of URLs that are not marked as unavailable
  @spec do_filter_unavailable_urls([String.t()] | nil, [String.t()]) :: [String.t()]
  defp do_filter_unavailable_urls(urls, unavailable_urls) do
    Enum.reject(urls || [], fn url -> url in unavailable_urls end)
  end

  # Updates error counts for an endpoint URL and marks it as unavailable if the error
  # threshold is exceeded.
  #
  # This function tracks errors for each endpoint URL and URL type combination. When
  # the error count reaches the maximum threshold, the endpoint is marked as
  # unavailable and monitoring is initiated.
  #
  # ## Parameters
  # - `url`: The endpoint URL to track errors for
  # - `json_rpc_named_arguments`: JSON-RPC configuration for the endpoint
  # - `url_type`: Type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)
  # - `state`: Current state containing error counts and unavailable endpoints
  #
  # ## Returns
  # - Updated state with modified error counts and unavailable endpoints
  @spec do_increase_error_counts(
          String.t(),
          EthereumJSONRPC.json_rpc_named_arguments(),
          url_type(),
          %{
            error_counts: %{
              String.t() => %{
                url_type() => %{count: non_neg_integer(), last_occasion: non_neg_integer()}
              }
            },
            unavailable_endpoints: %{url_type() => [String.t()]}
          }
        ) :: %{
          error_counts: %{
            String.t() => %{
              url_type() => %{count: non_neg_integer(), last_occasion: non_neg_integer()}
            }
          },
          unavailable_endpoints: %{url_type() => [String.t()]}
        }
  defp do_increase_error_counts(url, json_rpc_named_arguments, url_type, %{error_counts: error_counts} = state) do
    current_count = error_counts[url][url_type][:count]
    unavailable_endpoints = state.unavailable_endpoints[url_type]

    cond do
      url in unavailable_endpoints ->
        state

      is_nil(current_count) ->
        %{state | error_counts: Map.put(error_counts, url, %{url_type => %{count: 1, last_occasion: now()}})}

      current_count + 1 >= @max_error_count ->
        EndpointAvailabilityChecker.add_endpoint(
          put_in(json_rpc_named_arguments[:transport_options][:urls], [url]),
          url_type
        )

        log_url_unavailable(url, url_type, unavailable_endpoints, json_rpc_named_arguments)

        %{
          state
          | error_counts: Map.put(error_counts, url, Map.delete(error_counts[url], url_type)),
            unavailable_endpoints: %{state.unavailable_endpoints | url_type => [url | unavailable_endpoints]}
        }

      true ->
        %{
          state
          | error_counts: Map.put(error_counts, url, %{url_type => %{count: current_count + 1, last_occasion: now()}})
        }
    end
  end

  # Logs a warning message when a URL becomes unavailable.
  #
  # Includes information about fallback options based on the URL type and available
  # alternative URLs. WebSocket endpoints (`:ws`) are handled differently since they
  # don't support fallback URLs and alternative endpoints.
  #
  # ## Parameters
  # - `url`: The URL that became unavailable
  # - `url_type`: Type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)
  # - `unavailable_endpoints`: List of currently unavailable endpoints
  # - `json_rpc_named_arguments`: JSON-RPC configuration containing transport options
  #
  # ## Returns
  # - `:ok`
  @spec log_url_unavailable(String.t(), url_type(), [String.t()], EthereumJSONRPC.json_rpc_named_arguments()) :: :ok
  defp log_url_unavailable(url, :ws, _unavailable_endpoints, _json_rpc_named_arguments) do
    Logger.warning("URL #{inspect(url)} is unavailable")
  end

  defp log_url_unavailable(url, url_type, unavailable_endpoints, json_rpc_named_arguments) do
    available_urls =
      url_type
      |> available_urls(unavailable_endpoints, json_rpc_named_arguments)
      |> Kernel.--([url])

    fallback_url_message =
      case {available_urls, fallback_url_set?(url_type, json_rpc_named_arguments)} do
        {[], true} -> "and there is no other #{url_type} url available, switching to fallback #{url_type} url"
        {[], false} -> "there is no other #{url_type} url available, and no fallback is set"
        _ -> "switching to another #{url_type} url"
      end

    Logger.warning("URL #{inspect(url)} is unavailable, #{fallback_url_message}")
  end

  # Logs an info message when a previously unavailable URL becomes available.
  #
  # Includes additional context about switching back from fallback URLs if applicable.
  #
  # ## Parameters
  # - `url`: The URL that became available
  # - `url_type`: Type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)
  # - `unavailable_endpoints`: List of currently unavailable endpoints
  # - `json_rpc_named_arguments`: JSON-RPC configuration containing transport options
  #
  # ## Returns
  # - `:ok`
  @spec log_url_available(String.t(), url_type(), [String.t()], EthereumJSONRPC.json_rpc_named_arguments()) :: :ok
  defp log_url_available(url, url_type, unavailable_endpoints, json_rpc_named_arguments) do
    available_urls = available_urls(url_type, unavailable_endpoints, json_rpc_named_arguments)

    message_extra =
      case {available_urls, fallback_url_set?(url_type, json_rpc_named_arguments)} do
        {[], true} -> ", switching back from fallback urls"
        _ -> ""
      end

    Logger.info("URL #{inspect(url)} of #{url_type} type is available now#{message_extra}")
  end

  # Returns a list of available URLs for the given URL type, excluding those marked as unavailable.
  #
  # First it gets URLs that correspond to the specific URL type in JSON-RPC transport
  # and then filters out unavailable ones.
  #
  # ## Parameters
  # - `url_type`: Type of endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)
  # - `unavailable_endpoints`: List of URLs currently marked as unavailable
  # - `json_rpc_named_arguments`: JSON-RPC configuration containing transport options
  #
  # ## Returns
  # - List of available URLs for the specified type
  @spec available_urls(url_type(), [String.t()], EthereumJSONRPC.json_rpc_named_arguments()) :: [String.t()]
  defp available_urls(url_type, unavailable_endpoints, json_rpc_named_arguments) do
    url_type
    |> CommonHelper.url_type_to_urls(json_rpc_named_arguments[:transport_options])
    |> do_filter_unavailable_urls(unavailable_endpoints)
  end

  # Checks if a fallback URL is configured for the given URL type.
  #
  # ## Parameters
  # - `url_type`: Type of URL to check (`:ws`, `:trace`, `:http`, or `:eth_call`)
  # - `json_rpc_named_arguments`: JSON-RPC configuration containing transport options
  #
  # ## Returns
  # - `true` if a fallback URL is configured for the given URL type
  # - `false` otherwise
  @spec fallback_url_set?(url_type(), EthereumJSONRPC.json_rpc_named_arguments()) :: boolean()
  defp fallback_url_set?(url_type, json_rpc_named_arguments) do
    case url_type do
      :http -> not is_nil(json_rpc_named_arguments[:transport_options][:fallback_urls])
      :trace -> not is_nil(json_rpc_named_arguments[:transport_options][:fallback_trace_urls])
      :eth_call -> not is_nil(json_rpc_named_arguments[:transport_options][:fallback_eth_call_urls])
      _ -> false
    end
  end

  @spec schedule_next_cleaning() :: reference()
  defp schedule_next_cleaning do
    Process.send_after(self(), :clear_old_records, @cleaning_interval)
  end

  @spec now() :: non_neg_integer()
  defp now, do: :os.system_time(:second)
end
