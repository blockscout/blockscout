defmodule BlockScoutWeb.LayoutView do
  use BlockScoutWeb, :view

  alias Plug.Conn

  @issue_url "https://github.com/poanetwork/blockscout/issues/new"

  alias BlockScoutWeb.SocialMedia

  def network_icon_partial do
    Keyword.get(application_config(), :network_icon) || "_network_icon.html"
  end

  def logo do
    Keyword.get(application_config(), :logo) || "/images/blockscout_logo.svg"
  end

  def logo_footer do
    Keyword.get(application_config(), :logo_footer) || Keyword.get(application_config(), :logo) || "/images/blockscout_logo.svg"
  end

  def subnetwork_title do
    Keyword.get(application_config(), :subnetwork) || "Sokol Testnet"
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

  def stakes_active do
    Keyword.get(application_config(), :stakes_active) || false
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
        user_agent -> user_agent
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

  def version do
    BlockScoutWeb.version()
  end

  def release_link(version) do
    release_link = Application.get_env(:block_scout_web, :release_link)

    if release_link == "" || release_link == nil do
      version
    else
      html_escape({:safe, "<a href=\"#{release_link}\" class=\"footer-link\" target=\"_blank\">#{version}</a>"})
    end
  end

  def ignore_version?("unknown"), do: true
  def ignore_version?(_), do: false

  def other_networks do
    :block_scout_web
    |> Application.get_env(:other_networks, [])
    |> Enum.reject(fn %{title: title} ->
      title == subnetwork_title()
    end)
  end

  def main_nets do
    Enum.reject(other_networks(), &Map.get(&1, :test_net?))
  end

  def test_nets do
    Enum.filter(other_networks(), &Map.get(&1, :test_net?))
  end

  def other_explorers do
    if Application.get_env(:block_scout_web, :link_to_other_explorers) do
      Application.get_env(:block_scout_web, :other_explorers, [])
    else
      []
    end
  end
end
