defmodule Explorer.Admin.Recovery do
  @moduledoc """
  Generates a recovery key to configure the application as an administrator.
  """

  use GenServer

  def child_spec([init_options]) do
    child_spec([init_options, []])
  end

  def child_spec([_init_options, _gen_server_options] = start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :permanent,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(init_options, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, init_options, gen_server_options)
  end

  def init(_) do
    send(self(), :load_key)

    {:ok, %{}}
  end

  # sobelow_skip ["Misc.FilePath", "Traversal"]
  def handle_info(:load_key, _state) do
    base_path = Application.app_dir(:explorer)
    file_path = Path.join([base_path, "priv/.recovery"])

    recovery_key =
      case File.read(file_path) do
        {:ok, <<recovery_key::binary-size(44)>>} ->
          recovery_key

        _ ->
          recovery_key = gen_secret()
          File.write(file_path, recovery_key)
          recovery_key
      end

    {:noreply, %{key: recovery_key}}
  end

  def handle_call(:recovery_key, _from, %{key: key} = state) do
    {:reply, key, state}
  end

  @spec key(GenServer.server()) :: String.t()
  def key(server) do
    GenServer.call(server, :recovery_key)
  end

  @doc false
  def gen_secret do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.encode64()
  end
end
