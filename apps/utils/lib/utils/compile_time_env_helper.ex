defmodule Utils.CompileTimeEnvHelper do
  @moduledoc """
  A module that helps with compile time environment variable handling and automatic
  module recompilation when environment variables change.

  ## Motivation

  Direct use of `Application.compile_env/3` causes error when runtime value
  of environment variable value do not match compile time value,
  this error halts the compilation and requires recompilation of the whole app.
  This module prevents this since module is being recompiled automatically when
  environment variable value changes. So, this module solves two issues:

  1. Compile time error is avoided, so the app can be run without whole recompilation.
  2. No need to recompile the whole app when environment variable value changes, that
   speed up compilation of different app versions.

  ## How It Works

  The module implements the `__mix_recompile__?/0` callback which Mix uses to determine
  if a module needs recompilation. It tracks the values of specified environment variables
  at compile time and triggers recompilation when these values change.

  ## Configuration

  Each key-value pair in the options represents:
  - Key: The desired module attribute name
  - Value: A list containing two elements:
    - First element: The application name (atom)
    - Second element: The configuration key or list of nested keys

  ## Examples

  Simple configuration:

    use Utils.CompileTimeEnvHelper,
      api_url: [:my_app, :api_url]

  Nested configuration:

    use Utils.CompileTimeEnvHelper,
      db_config: [:my_app, [:database, :config]],
      api_key: [:my_app, [:api, :credentials, :key]]

  ## Technical Details

  1. **Compile Time Value Tracking**
   The module stores the initial values of environment variables during compilation
   in a module attribute. These values are used as a reference point for the
   `__mix_recompile__?/0` function.

  2. **Recompilation Logic**
   When Mix checks if recompilation is needed, the module compares the current
   environment variable values with the stored ones. If any value has changed,
   it triggers recompilation of the module.
  """

  defmacro __using__(env_vars) do
    alias Utils.CompileTimeEnvHelper
    CompileTimeEnvHelper.__generate_attributes_and_recompile_functions__(env_vars)
  end

  def __generate_attributes_and_recompile_functions__(env_vars) do
    quote do
      Module.register_attribute(__MODULE__, :__compile_time_env_vars, accumulate: true)

      for {attribute_name, [app, key_or_path]} <- unquote(env_vars) do
        Module.put_attribute(
          __MODULE__,
          attribute_name,
          Application.compile_env(app, key_or_path)
        )

        Module.put_attribute(
          __MODULE__,
          :__compile_time_env_vars,
          {Application.compile_env(app, key_or_path), {app, key_or_path}}
        )
      end

      def __mix_recompile__? do
        @__compile_time_env_vars
        |> Enum.map(fn
          {value, {app, [key | path]}} -> value != get_in(Application.get_env(app, key), path)
          {value, {app, key}} -> value != Application.get_env(app, key)
        end)
        |> Enum.any?()
      end
    end
  end
end
