defmodule Indexer.NFTMediaHandler.Queue do
  @moduledoc """
  Queue for fetching media
  """

  use GenServer

  require Logger
  alias Explorer.Chain.Token.Instance
  alias Explorer.Prometheus.Instrumenter
  alias Explorer.Token.MetadataRetriever
  alias Indexer.NFTMediaHandler.Backfiller

  @queue_storage :queue_storage
  @tasks_in_progress :tasks_in_progress

  @doc """
  Processes new inserted NFT instances.
  Adds instances to the queue if the media handler is enabled.

  ## Parameters

    - token_instances: new NFTs to process.

  ## Returns

    token_instances as is.
  """
  @spec process_new_instances([Instance.t()]) :: [Instance.t()]
  def process_new_instances(token_instances) do
    process_new_instances_inner(token_instances, Application.get_env(:nft_media_handler, :enabled?))

    token_instances
  end

  defp process_new_instances_inner(_token_instances, false), do: :ignore

  defp process_new_instances_inner(token_instances, true) do
    filtered_token_instances =
      Enum.flat_map(token_instances, fn token_instance ->
        url = Instance.get_media_url_from_metadata_for_nft_media_handler(token_instance.metadata)

        if url do
          [{token_instance.token_contract_address_hash, token_instance.token_id, url}]
        else
          []
        end
      end)

    GenServer.cast(__MODULE__, {:add_to_queue, filtered_token_instances})
  end

  def get_urls_to_fetch(amount) do
    GenServer.call(__MODULE__, {:get_urls_to_fetch, amount})
  end

  def store_result(batch_result) do
    GenServer.cast(__MODULE__, {:finished, batch_result})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    File.mkdir("./dets")
    {:ok, queue} = :dets.open_file(@queue_storage, file: ~c"./dets/#{@queue_storage}", type: :bag)
    {:ok, in_progress} = :dets.open_file(@tasks_in_progress, type: :set, file: ~c"./dets/#{@tasks_in_progress}")

    Process.flag(:trap_exit, true)

    {:ok, {queue, in_progress, nil}}
  end

  def handle_cast(
        {:add_to_queue, []},
        {queue, in_progress, continuation}
      ) do
    {:noreply, {queue, in_progress, continuation}}
  end

  def handle_cast(
        {:add_to_queue, token_instances},
        {queue, in_progress, continuation} = state
      )
      when is_list(token_instances) do
    token_instances
    |> Enum.flat_map(&process_new_token_instance(&1, state))
    |> Instance.batch_upsert_cdn_results()

    {:noreply, {queue, in_progress, continuation}}
  end

  def handle_cast({:finished, batch_result}, {_queue, in_progress, _continuation} = state) do
    process_batch_result(batch_result, in_progress)
    {:noreply, state}
  end

  def handle_call({:get_urls_to_fetch, amount}, _from, {queue, in_progress, continuation} = state) do
    {high_priority_urls, continuation} = fetch_urls_from_dets(queue, amount, continuation)
    now = System.monotonic_time()

    high_priority_instances = fetch_and_delete_instances_from_queue(queue, high_priority_urls, now)

    taken_amount = Enum.count(high_priority_urls)

    {urls, instances} =
      if taken_amount < amount do
        {instances_to_upsert, backfill_items} =
          (amount - taken_amount)
          |> Backfiller.get_instances()
          |> Enum.reduce({[], []}, &filter_fetched_backfill_url(&1, &2, state))

        instances_to_upsert |> Instance.batch_upsert_cdn_results()

        {low_priority_instances, low_priority_urls} =
          Enum.map_reduce(backfill_items, [], fn {url, instances}, acc ->
            {{url, instances, now}, [url | acc]}
          end)

        {high_priority_urls ++ low_priority_urls, high_priority_instances ++ low_priority_instances}
      else
        {high_priority_urls, high_priority_instances}
      end

    dets_insert_wrapper(in_progress, instances)
    {:reply, urls, {queue, in_progress, continuation}}
  end

  @doc """
  Implementation of terminate callback.
  Closes opened dets tables on application shutdown.
  """
  def terminate(_reason, {queue, in_progress, _continuation}) do
    :dets.close(queue)
    :dets.close(in_progress)
  end

  defp fetch_urls_from_dets(queue_table, amount, continuation) do
    query = {:"$1", :_}

    result =
      if is_nil(continuation) do
        :dets.match(queue_table, query, amount)
      else
        :dets.match(continuation)
      end

    case result do
      {:error, reason} ->
        Logger.error("Failed to fetch urls from dets: #{inspect(reason)}")
        {[], nil}

      :"$end_of_table" ->
        {[], nil}

      {urls, :"$end_of_table"} ->
        {urls |> List.flatten() |> Enum.uniq(), nil}

      {urls, continuation} ->
        {urls |> List.flatten() |> Enum.uniq(), continuation}
    end
  end

  defp fetch_and_delete_instances_from_queue(queue, urls, start_time) do
    Enum.map(urls, fn url ->
      instances =
        queue
        |> :dets.lookup(url)
        |> Enum.map(fn {_url, {_address_hash, _token_id} = instance} -> instance end)

      :dets.delete(queue, url)

      {url, instances, start_time}
    end)
  end

  defp cache_uniqueness_name do
    Application.get_env(:nft_media_handler, :cache_uniqueness_name)
  end

  defp filter_fetched_backfill_url(
         {url, backfill_instances} = input,
         {instances_to_upsert, instances_to_fetch},
         {_queue, in_progress, _continuation}
       ) do
    case :dets.lookup(in_progress, url) do
      [{_, instances, start_time}] ->
        Logger.debug("Media url already in progress: #{url}, will append to instances: #{inspect(backfill_instances)}")

        dets_insert_wrapper(in_progress, {url, instances ++ backfill_instances, start_time})
        {instances_to_upsert, instances_to_fetch}

      _ ->
        case Cachex.get(cache_uniqueness_name(), url) do
          {:ok, cached_result} when is_map(cached_result) ->
            Logger.debug("Media url already fetched: #{url}, will copy from cache to: #{inspect(backfill_instances)}")
            now = DateTime.utc_now()

            # credo:disable-for-lines:2 Credo.Check.Refactor.Nesting
            new_instances_to_upsert =
              Enum.map(backfill_instances, fn {token_address_hash, token_id} ->
                Map.merge(cached_result, %{
                  updated_at: now,
                  inserted_at: now,
                  token_contract_address_hash: token_address_hash,
                  token_id: token_id
                })
              end)

            {instances_to_upsert ++ new_instances_to_upsert, instances_to_fetch}

          _ ->
            {instances_to_upsert, [input | instances_to_fetch]}
        end
    end
  end

  defp dets_insert_wrapper(table, value) do
    case :dets.insert(table, value) do
      :ok -> :ok
      {:error, reason} -> Logger.error("Failed to insert into dets #{table}: #{inspect(reason)}")
    end
  end

  defp process_batch_result(result, in_progress_cache) do
    updated_at = DateTime.utc_now()

    {instances_to_upsert, results_to_cache} =
      Enum.reduce(result, {[], []}, fn {result, url}, {instances_acc, results_acc} ->
        case :dets.lookup(in_progress_cache, url) do
          [{_, instances, start_time}] ->
            :dets.delete(in_progress_cache, url)
            {result_base, result_for_cache} = process_result(result, url, start_time, updated_at)

            # credo:disable-for-lines:2 Credo.Check.Refactor.Nesting
            instances_to_upsert =
              Enum.map(instances, fn {token_contract_address_hash, token_id} ->
                Map.merge(result_base, %{token_contract_address_hash: token_contract_address_hash, token_id: token_id})
              end)

            {instances_acc ++ instances_to_upsert, [result_for_cache | results_acc]}

          _ ->
            Logger.error("Failed to find instances in in_progress dets for url: #{url}, result: #{inspect(result)}")
        end
      end)

    Cachex.put_many(cache_uniqueness_name(), results_to_cache)

    Instance.batch_upsert_cdn_results(instances_to_upsert)
  end

  defp process_result({:error, reason}, url, _start_time, updated_at) do
    cdn_upload_error = reason |> inspect() |> MetadataRetriever.truncate_error()

    result_base = %{
      thumbnails: nil,
      media_type: nil,
      updated_at: updated_at,
      inserted_at: updated_at,
      cdn_upload_error: cdn_upload_error
    }

    Instrumenter.increment_failed_uploading_media_number()

    {result_base, {url, %{thumbnails: nil, media_type: nil, cdn_upload_error: cdn_upload_error}}}
  end

  defp process_result({result, media_type}, url, start_time, updated_at) when is_list(result) do
    result_base = %{
      thumbnails: result,
      media_type: Instance.media_type_to_string(media_type),
      updated_at: updated_at,
      inserted_at: updated_at,
      cdn_upload_error: nil
    }

    Instrumenter.increment_successfully_uploaded_media_number()

    Instrumenter.media_processing_time(
      System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond) / 1000
    )

    {result_base,
     {url,
      %{
        thumbnails: result,
        media_type: Instance.media_type_to_string(media_type),
        cdn_upload_error: nil
      }}}
  end

  defp process_new_token_instance({token_address_hash, token_id, media_url}, {queue, in_progress, _continuation}) do
    case :dets.lookup(in_progress, media_url) do
      [{_, instances, start_time}] ->
        Logger.debug(
          "Media url already in progress: #{media_url}, will append to instances: {#{to_string(token_address_hash)}, #{token_id}} "
        )

        dets_insert_wrapper(in_progress, {media_url, [{token_address_hash, token_id} | instances], start_time})
        []

      _ ->
        case Cachex.get(cache_uniqueness_name(), media_url) do
          {:ok, cached_result} when is_map(cached_result) ->
            Logger.debug(
              "Media url already fetched: #{media_url}, will take result from cache to: {#{to_string(token_address_hash)}, #{token_id}} "
            )

            now = DateTime.utc_now()

            [
              Map.merge(cached_result, %{
                updated_at: now,
                inserted_at: now,
                token_contract_address_hash: token_address_hash,
                token_id: token_id
              })
            ]

          _ ->
            dets_insert_wrapper(queue, {media_url, {token_address_hash, token_id}})
            []
        end
    end
  end
end
