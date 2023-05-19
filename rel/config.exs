import Config

# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

defer = fn fun ->
  apply(fun, [])
end

app_root = fn ->
  if String.contains?(File.cwd!(), "apps") do
    Path.join([File.cwd!(), "/../../"])
  else
    File.cwd!()
  end
end

cookie =
  defer.(fn ->
    cookie_bytes =
      :crypto.strong_rand_bytes(32)
      |> Base.encode32()

    :ok = File.write!(Path.join(app_root.(), ".erlang_cookie"), cookie_bytes)
    :erlang.binary_to_atom(cookie_bytes, :utf8)
  end)

use Mix.Releases.Config,
    # This sets the default release built by `mix release`
    default_release: :default,
    # This sets the default environment used by `mix release`
    default_environment: config_env()

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/config/distillery.html


# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :dev do
  # If you are running Phoenix, you should make sure that
  # server: true is set and the code reloader is disabled,
  # even in dev mode.
  # It is recommended that you build with MIX_ENV=prod and pass
  # the --env flag to Distillery explicitly if you want to use
  # dev mode.
  set dev_mode: true
  set include_erts: false
  set cookie: :"i6E,!mJ6|E&|.VPaDywo@N.o}BgmC$UdKXW[aK,(@U0Asfpp/NergA;CR%YW4;i6"
end

environment :prod do
  set include_erts: true
  set include_src: false
  set cookie: cookie
  set vm_args: "rel/vm.args"
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :blockscout do
  set version: "5.1.5-beta"
  set applications: [
    :runtime_tools,
    block_scout_web: :permanent,
    ethereum_jsonrpc: :permanent,
    explorer: :permanent,
    indexer: :permanent
  ]
  set commands: [
    migrate: "rel/commands/migrate.sh",
    seed: "rel/commands/seed.sh",
  ]
end
