defmodule Explorer.ThirdPartyIntegrations.Dynamic.Strategy do
  @moduledoc """
  JWKS fetching strategy for Dynamic
  """
  use GenServer, restart: :transient

  alias Explorer.ThirdPartyIntegrations.Dynamic
  alias JokenJwks.{DefaultStrategyTemplate, SignerMatchStrategy}

  @behaviour SignerMatchStrategy

  def init_opts(opts) do
    url = Application.get_env(:explorer, Dynamic)[:url]
    Keyword.merge(opts, jwks_url: url)
  end

  @impl SignerMatchStrategy
  def match_signer_for_kid(kid, opts),
    do: DefaultStrategyTemplate.match_signer_for_kid(__MODULE__, kid, opts)

  @doc false
  def start_link(opts), do: DefaultStrategyTemplate.start_link(__MODULE__, opts)

  # Server (callbacks)
  @doc false
  @impl GenServer
  def init(opts) do
    # with this trick first fetch is done immediately and asynchronously, no application startup delay
    # and no `:time_interval` time without keys after application startup
    case DefaultStrategyTemplate.init(__MODULE__, opts |> Keyword.put(:time_interval, 0)) do
      {:ok, state} -> {:ok, state |> Keyword.put(:time_interval, opts[:time_interval] || 15 * 1_000)}
      other -> other
    end
  end

  @doc false
  @impl GenServer
  def handle_info(:check_fetch, state) do
    DefaultStrategyTemplate.check_fetch(__MODULE__, state[:jwks_url], state)
    DefaultStrategyTemplate.schedule_check_fetch(__MODULE__, state[:time_interval])

    {:noreply, state}
  end
end
