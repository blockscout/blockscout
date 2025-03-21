defmodule BlockScoutWeb.Routers.ChainTypeScope do
  @moduledoc """
  Provides macros for defining chain-specific routes that are checked at
  runtime.
  """

  defmacro __using__(_) do
    quote do
      import BlockScoutWeb.Routers.ChainTypeScope
    end
  end

  @doc """
  Defines a scope that's restricted to a specific chain type at runtime.

  ## Examples

      chain_scope :polygon_zkevm do
        get("/zkevm-batch/:batch_number", V2.TransactionController, :polygon_zkevm_batch)
      end
  """
  defmacro chain_scope(chain_type, opts \\ [], do: block) do
    pipeline_name = String.to_atom("chain_type_scope_#{chain_type}")

    quote do
      # Define pipeline if not already defined
      unless Module.has_attribute?(__MODULE__, unquote(pipeline_name)) do
        pipeline unquote(pipeline_name) do
          plug(BlockScoutWeb.Plug.CheckChainType, unquote(chain_type))
        end

        # Add an attribute to track that we've defined this pipeline
        Module.register_attribute(__MODULE__, unquote(pipeline_name), accumulate: false)
        Module.put_attribute(__MODULE__, unquote(pipeline_name), true)
      end

      # Use the pipeline in a scope
      scope "/", unquote(opts) do
        pipe_through(unquote(pipeline_name))
        unquote(block)
      end
    end
  end
end
