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

  # A macro that sets up compile-time environment variable handling.
  #
  # ## How it works under the hood
  #
  # 1. When you `use Utils.CompileTimeEnvHelper`, it triggers this macro
  # 2. The macro processes your environment configuration and generates necessary code
  #    using metaprogramming (the `quote` block)
  #
  # ## Example of generated code
  #
  # When you write:
  #     use Utils.CompileTimeEnvHelper,
  #       api_url: [:my_app, :api_url]
  #
  # It generates code similar to:
  #     Module.register_attribute(__MODULE__, :__compile_time_env_vars, accumulate: true)
  #   
  #     # Creates @api_url attribute with the compile-time value
  #     Module.put_attribute(
  #       __MODULE__,
  #       :api_url,
  #       Application.compile_env(:my_app, :api_url)
  #     )
  #    
  #     # Stores the value for recompilation checking
  #     Module.put_attribute(
  #       __MODULE__,
  #       :__compile_time_env_vars,
  #       {Application.compile_env(:my_app, :api_url), {:my_app, :api_url}}
  #     )
  defmacro __using__(env_vars) do
    alias Utils.CompileTimeEnvHelper
    CompileTimeEnvHelper.__generate_attributes_and_recompile_functions__(env_vars)
  end

  @doc """
  Generates the code needed for compile-time environment variable handling.

  ## Technical Details

  This function uses `quote` to create an Abstract Syntax Tree (AST) that will be
  injected into the module using this helper. The generated code:

  1. Creates a module attribute to accumulate environment variables:
     ```
     Module.register_attribute(__MODULE__, :__compile_time_env_vars, accumulate: true)
     ```

  2. For each environment variable in the configuration:
     - Creates a module attribute with the compile-time value
     - Stores the value and path for recompilation checking

  3. Generates the `__mix_recompile__?/0` function that Mix uses to determine
     if the module needs recompilation

  ## Example

  Given configuration:
      api_url: [:my_app, :api_url]
      db_host: [:my_app, [:database, :host]]

  This function generates:
      # Module attributes for direct access
      @api_url Application.compile_env(:my_app, :api_url)
      @db_host Application.compile_env(:my_app, [:database, :host])

      # Storage for recompilation checking
      @__compile_time_env_vars [
        {<api_url_value>, {:my_app, :api_url}},
        {<db_host_value>, {:my_app, [:database, :host]}}
      ]

      # Recompilation check function
      def __mix_recompile__? do
        # Check if any values changed
      end

  ## Understanding the Quote Block

  The `quote do ... end` block is Elixir's metaprogramming feature that:
  1. Creates a template of code instead of executing it immediately
  2. This template will be injected into the module that uses this helper
  3. The code inside `quote` is executed when the module is compiled
  """
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
