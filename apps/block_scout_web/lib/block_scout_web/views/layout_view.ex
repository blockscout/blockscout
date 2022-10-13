defmodule BlockScoutWeb.LayoutView do
  use BlockScoutWeb, :view

  alias Explorer.{Chain, CustomContractsHelpers}
  alias Plug.Conn
  alias Poison.Parser
  import BlockScoutWeb.AddressView, only: [from_address_hash: 1]

  @issue_url "https://github.com/celo-org/celo-monorepo/issues/new"

  @default_other_networks [
    %{
      title: "Celo Mainnet",
      url: "https://explorer.celo.org/mainnet",
      test_net?: false
    },
    %{
      title: "Celo Alfajores",
      url: "https://explorer.celo.org/alfajores",
      test_net?: true
    },
    %{
      title: "Celo Baklava",
      url: "https://explorer.celo.org/baklava",
      test_net?: true
    }
  ]

  alias BlockScoutWeb.SocialMedia

  def logo do
    Keyword.get(application_config(), :logo)
  end

  def logo_footer do
    Keyword.get(application_config(), :logo_footer) || Keyword.get(application_config(), :logo)
  end

  def logo_text do
    Keyword.get(application_config(), :logo_text) || nil
  end

  def subnetwork_title do
    Keyword.get(application_config(), :subnetwork) || "Sokol"
  end

  def network_title do
    Keyword.get(application_config(), :network) || "Celo"
  end

  defp application_config do
    Application.get_env(:block_scout_web, BlockScoutWeb.Chain)
  end

  def configured_social_media_services do
    SocialMedia.links()
  end

  def issue_link(conn) do
    params = [
      labels: "BlockScout",
      body: issue_body(conn),
      title: subnetwork_title() <> ": <Issue Title>"
    ]

    [@issue_url, "?", URI.encode_query(params)]
  end

  defp issue_body(conn) do
    user_agent =
      case Conn.get_req_header(conn, "user-agent") do
        [] -> "unknown"
        [user_agent] -> if String.valid?(user_agent), do: user_agent, else: "unknown"
        _other -> "unknown"
      end

    """
    *Describe your issue here.*

    ### Environment
    * Elixir Version: #{System.version()}
    * Erlang Version: #{System.otp_release()}
    * BlockScout Version: #{version()}

    * User Agent: `#{user_agent}`

    ### Steps to reproduce

    *Tell us how to reproduce this issue. If possible, push up a branch to your fork with a regression test we can run to reproduce locally.*

    ### Expected Behaviour

    *Tell us what should happen.*

    ### Actual Behaviour

    *Tell us what happens instead.*
    """
  end

  def version, do: BlockScoutWeb.version()
  def segment_key, do: BlockScoutWeb.segment_key()
  def network_path, do: BlockScoutWeb.network_path()
  def coin_name(), do: BlockScoutWeb.coin_name()
  def subnetwork(), do: BlockScoutWeb.subnetwork()
  def chain_id(), do: BlockScoutWeb.chain_id()
  def json_rpc(), do: BlockScoutWeb.json_rpc()

  def release_link(version) do
    release_link_env_var = Application.get_env(:block_scout_web, :release_link)

    release_link =
      cond do
        version == "" || version == nil ->
          nil

        release_link_env_var == "" || release_link_env_var == nil ->
          if String.length(version) == 40 do
            "https://github.com/celo-org/blockscout/commit/" <> version
          else
            "https://github.com/celo-org/blockscout/releases/tag/" <> version
          end

        true ->
          release_link_env_var
      end

    if release_link == nil do
      ""
    else
      html_escape({:safe, "<a href=\"#{release_link}\" class=\"footer-link\" target=\"_blank\">#{version}</a>"})
    end
  end

  def ignore_version?("unknown"), do: true
  def ignore_version?(_), do: false

  def other_networks do
    get_other_networks =
      if Application.get_env(:block_scout_web, :other_networks) do
        try do
          :block_scout_web
          |> Application.get_env(:other_networks)
          |> Parser.parse!(%{keys: :atoms!})
        rescue
          _ ->
            []
        end
      else
        @default_other_networks
      end

    get_other_networks
    |> Enum.reject(fn %{title: title} ->
      title == subnetwork_title()
    end)
    |> Enum.sort()
  end

  def main_nets(nets) do
    nets
    |> Enum.reject(&Map.get(&1, :test_net?))
  end

  def test_nets(nets) do
    nets
    |> Enum.filter(&Map.get(&1, :test_net?))
  end

  def dropdown_nets do
    other_networks()
    |> Enum.reject(&Map.get(&1, :hide_in_dropdown?))
  end

  def dropdown_main_nets do
    dropdown_nets()
    |> main_nets()
  end

  def dropdown_test_nets do
    dropdown_nets()
    |> test_nets()
  end

  def dropdown_head_main_nets do
    dropdown_nets()
    |> main_nets()
    |> Enum.reject(&Map.get(&1, :other?))
  end

  def dropdown_other_nets do
    dropdown_nets()
    |> main_nets()
    |> Enum.filter(&Map.get(&1, :other?))
  end

  def other_explorers do
    if Application.get_env(:block_scout_web, :link_to_other_explorers) do
      decode_json(Application.get_env(:block_scout_web, :other_explorers, []))
    else
      []
    end
  end

  defp list(component) do
    if Application.get_env(:block_scout_web, component) do
      try do
        :block_scout_web
        |> Application.get_env(component)
        |> Parser.parse!(%{keys: :atoms!})
      rescue
        _ ->
          []
      end
    else
      []
    end
  end

  def swap_list do
    list(:swap)
  end

  def defi_list do
    list(:defi)
  end

  def wallet_list do
    list(:wallet_list)
  end

  def nft_list do
    list(:nft_list)
  end

  def connect_list do
    list(:connect_list)
  end

  def spend_list do
    list(:spend_list)
  end

  def finance_tools_list do
    list(:finance_tools_list)
  end

  def resources_list do
    list(:resources)
  end

  def learning_list do
    list(:learning)
  end

  def apps_list do
    list(:external_apps)
  end

  defp decode_json(data) do
    Jason.decode!(~s(#{data}))
  rescue
    _ -> []
  end

  def webapp_url(conn) do
    :block_scout_web
    |> Application.get_env(:webapp_url)
    |> validate_url()
    |> case do
      :error -> chain_path(conn, :show)
      {:ok, url} -> url
    end
  end

  def api_url do
    :block_scout_web
    |> Application.get_env(:api_url)
    |> validate_url()
    |> case do
      :error -> ""
      {:ok, url} -> url
    end
  end

  def external_apps_list do
    if Application.get_env(:block_scout_web, :external_apps) do
      try do
        :block_scout_web
        |> Application.get_env(:external_apps)
        |> Parser.parse!(%{keys: :atoms!})
      rescue
        _ ->
          []
      end
    else
      []
    end
  end

  defp validate_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: nil} -> :error
      _ -> {:ok, url}
    end
  end

  defp validate_url(_), do: :error
end
