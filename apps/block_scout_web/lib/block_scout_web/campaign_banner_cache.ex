defmodule BlockScoutWeb.CampaignBannerCache do
  @moduledoc """
  Handles providing data to show banner
  """

  use GenServer

  require Logger

  alias __MODULE__

  config = Application.get_env(:block_scout_web, __MODULE__)
  @default_campaign_data []

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    refresh_interval =
      "CAMPAIGN_BANNER_REFRESH_INTERVAL"
      |> System.get_env("60")
      |> Integer.parse()
      |> case do
        {integer, ""} -> integer
        _ -> 60
      end

    backend_url = System.get_env("CAMPAIGN_BANNER_BACKEND_URL", "")
    should_fetch_campaign_data? = backend_url != ""

    state = %{
      config: %{
        backend_url: backend_url,
        refresh_interval: refresh_interval
      },
      campaign_data: @default_campaign_data
    }

    if should_fetch_campaign_data? do
      {:ok, state, {:continue, :fetch_campaign_data}}
    else
      {:ok, state}
    end
  end

  @impl true
  def handle_continue(:fetch_campaign_data, state) do
    fetch_and_reschedule(state)

    {:noreply, state}
  end

  @impl true
  def handle_info(:fetch_campaign_data, state) do
    fetch_and_reschedule(state)

    {:noreply, state}
  end

  @impl true
  def handle_info({:update_campaign_data, campaign_data}, state) do
    new_state =
      state
      |> put_in([:campaign_data], campaign_data)

    {:noreply, new_state}
  end

  def handle_info({ref, :ok}, state) when is_pid(ref), do: {:noreply, state}

  def handle_info(_, state) do
    Logger.warn("Unknown message received")

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_campaign_data, _, %{campaign_data: campaign_data} = state) do
    {:reply, campaign_data, state}
  end

  def get_campaign_data do
    GenServer.call(__MODULE__, :get_campaign_data)
  end

  def update_campaign_data(campaign_data) do
    send(__MODULE__, {:update_campaign_data, campaign_data})
  end

  defp fetch_and_reschedule(%{config: %{refresh_interval: refresh_interval, backend_url: backend_url}}) do
    do_fetch_campaign_data(backend_url)

    Process.send_after(self(), :fetch_campaign_data, :timer.minutes(refresh_interval))
  end

  defp fetch_campaign_backend_data(backend_url) do
    case HTTPoison.get(backend_url, [], follow_redirect: true, timeout: 5_000) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        {:ok, body}

      _ ->
        {:error, :error_calling_backend_api}
    end
  end

  defp parse_campaign_backend_data(backend_response) do
    case Jason.decode(backend_response, keys: :atoms) do
      {:ok, response} ->
        case response do
          %{status: "success", data: campaigns_data} ->
            {:ok, campaigns_data}

          _ ->
            {:error, :backend_response_malformed}
        end

      _ ->
        {:error, :json_malformed}
    end
  end

  defp check_item_payload(%{
         campaign: campaign,
         content: content,
         ctaContent: cta_content,
         ctaUrl: cta_url,
         preset: preset
       })
       when is_bitstring(campaign) and is_bitstring(content) and is_bitstring(cta_content) and
              is_bitstring(cta_url) and is_bitstring(preset),
       do: true

  defp check_item_payload(payload) do
    Logger.warn("Unknown payload encountered: #{inspect(payload)}")

    false
  end

  defp prepare_item_payload(%{
         campaign: name,
         content: content,
         ctaContent: cta_content,
         ctaUrl: cta_url,
         preset: preset
       }) do
    %{
      id: name |> String.downcase() |> String.replace(" ", "-"),
      content: content,
      cta_content: cta_content,
      cta_url: cta_url,
      preset: preset
    }
  end

  defp prepare_campaign_data(raw_campaigns_data) when is_list(raw_campaigns_data) do
    {:ok,
     raw_campaigns_data
     |> Enum.filter(&check_item_payload/1)
     |> Enum.map(&prepare_item_payload/1)}
  end

  defp prepare_campaign_data(_), do: []

  defp do_fetch_campaign_data(backend_url) do
    Explorer.TaskSupervisor
    |> Task.Supervisor.start_child(
      fn ->
        Logger.info("Fetching campaign data")

        with {:ok, backend_response} <- fetch_campaign_backend_data(backend_url),
             {:ok, raw_campaign_data} <- parse_campaign_backend_data(backend_response),
             {:ok, campaign_data} <- prepare_campaign_data(raw_campaign_data) do
          CampaignBannerCache.update_campaign_data(campaign_data)

          Logger.info("Successfuly fetched campaign data")
        else
          {:error, reason} ->
            Logger.error("Error fetching campaign data: #{reason}")

          _ ->
            Logger.error("Other error fetching campaign data")
        end
      end,
      timeout: 5_000,
      on_timeout: :kill_task
    )
  end
end
