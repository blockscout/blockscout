defmodule Utils.RuntimeEnvHelper do
  @moduledoc """
  A module that provides runtime access to environment variables with a similar
  interface to CompileTimeEnvHelper, but without requiring recompilation when
  values change.

  This module automatically:

  1. Defines a sibling module with your environment functions
  2. Imports the functions into your main module
  3. Makes them available at both compile time (when referenced within a macro)
     and runtime

  ## Usage

  ```elixir
  defmodule MyModule do
    use Utils.RuntimeEnvHelper,
      mud_enabled?: [:explorer, [Explorer.Chain.Mud, :enabled]],
      api_enabled?: [:block_scout_web, :api_enabled]

    pipeline :mud do
      plug(CheckFeature, feature_check: &mud_enabled?/0)
    end

    def process do
      if api_enabled?() do
        # API-specific logic
      end
    end
  end
  ```
  """

  defmacro __using__(env_vars) do
    # Extract caller module information
    caller_module = __CALLER__.module
    # Generate the runtime env module name
    sibling_module = Module.concat(caller_module, "__RuntimeEnvs__")

    sibling_module_body =
      for {var_name, path} <- env_vars do
        quote do
          def unquote(var_name)() do
            # credo:disable-for-next-line Credo.Check.Design.AliasUsage
            Utils.RuntimeEnvHelper.get_env(unquote(path))
          end
        end
      end

    # Define the module outside the caller's context
    Module.create(sibling_module, sibling_module_body, __CALLER__)

    # Return only the import directive for the caller module
    quote do
      import unquote(sibling_module)
    end
  end

  @doc """
  Gets an environment variable value at runtime based on its path.

  ## Examples

      iex> Utils.RuntimeEnvHelper.get_env([:my_app, :api_url])
      "https://example.com"

      iex> Utils.RuntimeEnvHelper.get_env([:my_app, [Database, :host]])
      "localhost"
  """
  @spec get_env([atom() | [atom()]]) :: any()
  def get_env([app, [key | path]]) when is_list(path) do
    app
    |> Application.get_env(key)
    |> get_in(path)
  end

  def get_env([app, key]) do
    Application.get_env(app, key)
  end
end
