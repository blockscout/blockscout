defmodule BlockScoutWeb.LayoutView do
  use BlockScoutWeb, :view

  alias EthereumJSONRPC.Variant
  alias Explorer.{Chain, Helper}
  alias Poison.Parser

  import BlockScoutWeb.APIDocsView, only: [blockscout_url: 1]

  @default_other_networks [
    %{
      title: "POA",
      url: "https://blockscout.com/poa/core"
    },
    %{
      title: "Sokol",
      url: "https://blockscout.com/poa/sokol",
      test_net?: true
    },
    %{
      title: "Gnosis Chain",
      url: "https://blockscout.com/xdai/mainnet"
    },
    %{
      title: "Ethereum Classic",
      url: "https://blockscout.com/etc/mainnet",
      other?: true
    },
    %{
      title: "RSK",
      url: "https://blockscout.com/rsk/mainnet",
      other?: true
    }
  ]

  alias BlockScoutWeb.SocialMedia

  def logo do
    Keyword.get(application_config(), :logo)
  end

  def logo_footer do
    Keyword.get(application_config(), :footer)[:logo] || Keyword.get(application_config(), :logo)
  end

  def logo_text do
    Keyword.get(application_config(), :logo_text) || nil
  end

  def subnetwork_title do
    Keyword.get(application_config(), :subnetwork) || "Sokol"
  end

  def network_title do
    Keyword.get(application_config(), :network) || "POA"
  end

  defp application_config do
    Application.get_env(:block_scout_web, BlockScoutWeb.Chain)
  end

  def configured_social_media_services do
    SocialMedia.links()
  end

  @doc """
  Generates URL for new issue creation on Github
  """
  @spec issue_link() :: [term()]
  def issue_link do
    {os_family, os_name} = :os.type()

    params = [
      template: "bug_report.yml",
      labels: "triage",
      "backend-version": version(),
      "elixir-version": "Elixir #{System.version()} Erlang/OTP #{System.otp_release()}",
      "os-version": "#{os_family} #{os_name}",
      "archive-node-type": Variant.get(),
      "additional-information": "The issue happened at #{subnetwork_title()} Blockscout instance"
    ]

    issue_url = "#{Application.get_env(:block_scout_web, :footer)[:github_link]}/issues/new"

    [issue_url, "?", URI.encode_query(params)]
  end

  def version do
    BlockScoutWeb.version()
  end

  def release_link(""), do: ""
  def release_link(nil), do: ""

  def release_link(version) do
    release_link_env_var = Application.get_env(:block_scout_web, :release_link)

    release_link =
      if release_link_env_var == "" || release_link_env_var == nil do
        release_link_from_version(version)
      else
        release_link_env_var
      end

    html_escape({:safe, "<a href=\"#{release_link}\" class=\"footer-link\" target=\"_blank\">#{version}</a>"})
  end

  def release_link_from_version(version) do
    repo = "https://github.com/blockscout/blockscout"

    if String.contains?(version, "+commit.") do
      commit_hash =
        version
        |> String.split("+commit.")
        |> List.last()

      repo <> "/commit/" <> commit_hash
    else
      repo <> "/releases/tag/" <> version
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

  @spec other_explorers() :: map()
  def other_explorers do
    if Application.get_env(:block_scout_web, :footer)[:link_to_other_explorers] do
      decode_other_explorers_json(Application.get_env(:block_scout_web, :footer)[:other_explorers])
    else
      %{}
    end
  end

  @spec decode_other_explorers_json(nil | String.t()) :: map()
  defp decode_other_explorers_json(nil), do: %{}

  defp decode_other_explorers_json(data) do
    Jason.decode!(~s(#{data}))
  rescue
    _ -> %{}
  end

  def webapp_url(conn) do
    :block_scout_web
    |> Application.get_env(:webapp_url)
    |> Helper.validate_url()
    |> case do
      :error -> chain_path(conn, :show)
      {:ok, url} -> url
    end
  end

  def api_url do
    :block_scout_web
    |> Application.get_env(:api_url)
    |> Helper.validate_url()
    |> case do
      :error -> ""
      {:ok, url} -> url
    end
  end

  def apps_list do
    apps = Application.get_env(:block_scout_web, :apps)

    if apps do
      try do
        apps
        |> Parser.parse!(%{keys: :atoms!})
      rescue
        _ ->
          []
      end
    else
      []
    end
  end

  def sign_in_link do
    if Mix.env() == :test do
      "/auth/auth0"
    else
      Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:path] <> "/auth/auth0"
    end
  end

  def sign_out_link do
    client_id = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)[:client_id]
    return_to = blockscout_url(true) <> "/auth/logout"
    logout_url = Application.get_env(:ueberauth, Ueberauth)[:logout_url]

    if client_id && return_to && logout_url do
      params = [
        client_id: client_id,
        returnTo: return_to
      ]

      [logout_url, "?", URI.encode_query(params)]
    else
      []
    end
  end
end
