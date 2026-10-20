# Blockscout Elixir container for Apple `container`

This directory holds a container setup for Elixir tasks on macOS. It uses
Apple `container` (https://github.com/apple/container). The container runs `mix compile`,
`mix test`, credo, cspell, and dialyzer. It does not run VS Code or the
Blockscout server.

The setup copies the devcontainer from `.devcontainer/` with two
differences:

- PostgreSQL 17 runs inside the same container, at `localhost:5432`. Apple
  `container` has no compose and no shared network namespace, so this keeps
  the database URLs of the devcontainer.
- The container sees only the project directory.

As in the devcontainer, the project directory is mounted at `/workspace`, and
the database files live in a named volume. `_build`, `deps`, and `priv/plts`
stay in the project directory. Both containers use the same paths, so you can
switch between them without a recompile.

## Requirements

- Apple silicon Mac with Apple `container` 1.5 or later.
- The container system service runs. To start it, run `container system start`.

## Usage

Run the commands from the project root.

To start the container, run:

```bash
.devcontainer/apple-container/bs-container up
```

The first start builds the `bs-elixir-dev:latest` image. Later starts reuse
the image and the container.

To open a shell inside the container, run:

```bash
.devcontainer/apple-container/bs-container shell
```

The other subcommands are `build`, `down`, `rm`, `status`, `logs`, `name`,
and `reset-volumes`. The `reset-volumes` subcommand deletes the container and
its database volume.

You can change the resources with environment variables before `up`:
`BS_CONTAINER_CPUS` (default 8) and `BS_CONTAINER_MEMORY` (default 12G).
If `up` creates a new container, it uses these values. To apply new values
to an existing container, run `rm` and then `up`.

## Clones and worktrees

Each project directory, a clone or a worktree, gets its own container and its
own database volume, as with devcontainer. The container name comes from the
directory name and a hash of its full path, for example
`bs-elixir-1a2b3c4d`. The volume name is the container name plus `-pgdata`. If a
container for the directory already exists, `bs-container` keeps its name.
To use a different name, set `BS_CONTAINER_NAME` before you run
`bs-container`. To see the name, run `bs-container name`.

## Agent skills

The compile, test, code-quality, and dialyzer scripts call the `devcontainer`
skill script (`.agents/skills/devcontainer/scripts/exec.sh`). The script runs
the command in the Apple container or in the docker devcontainer.

To select the container, set `BS_CONTAINER_RUNTIME` in
`.devcontainer/.blockscout_config` to `apple` or `devcontainer`. The script
reads only this line from the file. If the variable is not set, the script
selects the container as follows:

1. If the `container` CLI is installed, the script uses the Apple container.
   If no Apple container runs, it uses a running docker devcontainer.
2. If only the `devcontainer` CLI or docker is installed, the script uses the
   docker devcontainer.
3. If none of them is installed, the script shows the ways to start a
   container.

The script finds the Apple container by its `bs.project_root` label. The
label holds the absolute project path. If no container runs, the error
message gives the start command for the selected tool.

## Known issues

The `init` mode of the compile script fails with
`Could not start Hex` on a fresh container. The image already has Hex, so
use the standard mode for the first compile.
