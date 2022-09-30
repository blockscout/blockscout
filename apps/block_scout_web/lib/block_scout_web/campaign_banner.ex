defmodule BlockScoutWeb.CampaignBanner do
  @moduledoc """
  Handles providing data to show banner
  """

  use GenServer

  require Logger

  config = Application.get_env(:block_scout_web, __MODULE__)
  @backend_url Keyword.get(config, :backend_url, "")
  @refresh_interval Keyword.get(config, :refresh_interval, 60)

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    if @backend_url != "" do
      Process.send_after(self(), :refresh_campaign_data, :timer.minutes(@refresh_interval))

      {:ok, refresh_campaign_data()}
    else
      {:ok, []}
    end
  end

  @impl true
  def handle_info(:refresh_campaign_data, _) do
    Process.send_after(self(), :refresh_campaign_data, :timer.minutes(@refresh_interval))

    {:noreply, refresh_campaign_data()}
  end

  @impl GenServer
  def handle_call(:get_campaign_data, _, state) do
    {:reply, state, state}
  end

  def get_campaign_data do
    GenServer.call(__MODULE__, :get_campaign_data)
  end

  defp fetch_campaign_backend_data do
    case HTTPoison.get(@backend_url, [], follow_redirect: true) do
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

  defp prepare_campaign_data(raw_campaigns_data) do
    {:ok,
     raw_campaigns_data
     |> Enum.map(fn %{
                      campaign: name,
                      content: content,
                      ctaContent: cta_content,
                      ctaUrl: cta_url,
                      preset: preset
                    } ->
       %{
         id: name |> String.downcase() |> String.replace(" ", "-"),
         content: content,
         cta_content: cta_content,
         cta_url: cta_url,
         preset: preset
       }
     end)}
  end

  defp refresh_campaign_data do
    Logger.info("Refreshing campaign data")

    with {:ok, backend_response} <- fetch_campaign_backend_data(),
         {:ok, raw_campaign_data} <- parse_campaign_backend_data(backend_response),
         {:ok, campaign_data} <- prepare_campaign_data(raw_campaign_data) do
      Logger.info("Successfuly refreshed campaign data")

      campaign_data
    else
      {:error, reason} ->
        Logger.error("Error refreshing campaign data: #{reason}")

        []

      _ ->
        []
    end
  end
end
