defmodule BlockScoutWeb.LayoutView do
  use BlockScoutWeb, :view

  alias Plug.Conn
  alias Poison.Parser

  @issue_url "https://github.com/poanetwork/blockscout/issues/new"
  @default_other_networks [
    %{
      title: "POA Core",
      url: "https://blockscout.com/poa/core"
    },
    %{
      title: "POA Sokol",
      url: "https://blockscout.com/poa/sokol",
      test_net?: true
    },
    %{
      title: "xDai Chain",
      url: "https://blockscout.com/poa/dai"
    },
    %{
      title: "Ethereum Mainnet",
      url: "https://blockscout.com/eth/mainnet"
    },
    %{
      title: "Kovan Testnet",
      url: "https://blockscout.com/eth/kovan",
      test_net?: true
    },
    %{
      title: "Ropsten Testnet",
      url: "https://blockscout.com/eth/ropsten",
      test_net?: true
    },
    %{
      title: "Goerli Testnet",
      url: "https://blockscout.com/eth/goerli",
      test_net?: true
    },
    %{
      title: "Rinkeby Testnet",
      url: "https://blockscout.com/eth/rinkeby",
      test_net?: true
    },
    %{
      title: "Ethereum Classic",
      url: "https://blockscout.com/etc/mainnet",
      other?: true
    },
    %{
      title: "Aerum Mainnet",
      url: "https://blockscout.com/aerum/mainnet",
      other?: true
    },
    %{
      title: "Callisto Mainnet",
      url: "https://blockscout.com/callisto/mainnet",
      other?: true
    },
    %{
      title: "RSK Mainnet",
      url: "https://blockscout.com/rsk/mainnet",
      other?: true
    }
  ]

  alias BlockScoutWeb.SocialMedia

  def network_icon_partial do
    Keyword.get(application_config(), :network_icon) || "_network_icon.html"
  end

  def logo do
    Keyword.get(application_config(), :logo) || "/images/blockscout_logo.svg"
  end

  def logo_footer do
    Keyword.get(application_config(), :logo_footer) || Keyword.get(application_config(), :logo) ||
      "/images/blockscout_logo.svg"
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

  def version do
    BlockScoutWeb.version()
  end

  def release_link(version) do
    release_link_env_var = Application.get_env(:block_scout_web, :release_link)

    release_link =
      cond do
        version == "" || version == nil ->
          nil

        release_link_env_var == "" || release_link_env_var == nil ->
          "https://github.com/poanetwork/blockscout/releases/tag/" <> version

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
        :block_scout_web
        |> Application.get_env(:other_networks)
        |> Parser.parse!(%{keys: :atoms!})
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
      Application.get_env(:block_scout_web, :other_explorers, [])
    else
      []
    end
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

  defp validate_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: nil} -> :error
      _ -> {:ok, url}
    end
  end

  defp validate_url(_), do: :error
end
