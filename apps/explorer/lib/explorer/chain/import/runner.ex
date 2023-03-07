defmodule Explorer.Chain.Import.Runner do
  @moduledoc """
  Behaviour used by `Explorer.Chain.Import.all/1` to import data into separate tables.
  """

  alias Ecto.Multi

  @typedoc """
  A callback module that implements this module's behaviour.
  """
  @type t :: module

  @typedoc """
  Validated changes extracted from a valid `Ecto.Changeset` produced by the `t:changeset_function_name/0` in
  `c:ecto_schema_module/0`.
  """
  @type changes :: %{optional(atom) => term()}

  @typedoc """
  A list of `t:changes/0` to be imported by `c:run/3`.
  """
  @type changes_list :: [changes]

  @type changeset_function_name :: atom
  @type on_conflict :: :nothing | :replace_all | :update_coin_balance | :update_contract_code | Ecto.Query.t()

  @typedoc """
  Runner-specific options under `c:option_key/0` in all options passed to `c:run/3`.
  """
  @type options :: %{
          required(:params) => [map()],
          optional(:on_conflict) => on_conflict(),
          optional(:timeout) => timeout,
          optional(:with) => changeset_function_name()
        }

  @doc """
  Key in `t:all_options` used by this `Explorer.Chain.Import` behaviour implementation.
  """
  @callback option_key() :: atom()

  @doc """
  Row of markdown table explaining format of `imported` from the module for use in `all/1` docs.
  """
  @callback imported_table_row() :: %{value_type: String.t(), value_description: String.t()}

  @doc """
  The `Ecto.Schema` module that contains the `:changeset` function for validating `options[options_key][:params]`.
  """
  @callback ecto_schema_module() :: module()
  @callback run(Multi.t(), changes_list, %{optional(atom()) => term()}) :: Multi.t() | [any()]
  # @callback run_insert_only(Multi.t(), changes_list, %{optional(atom()) => term()}) :: Multi.t()
  @callback timeout() :: timeout()

  @doc """
  The optional list of runner-specific options.
  """
  @callback runner_specific_options() :: [atom()]

  @optional_callbacks runner_specific_options: 0
end
