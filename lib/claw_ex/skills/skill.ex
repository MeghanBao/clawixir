defmodule Clawixir.Skills.Skill do
  @moduledoc """
  Behaviour that all Clawixir skills/tools must implement.

  A skill module must export:
  - `name/0`       — unique string identifier (used by the LLM to call the tool)
  - `definition/0` — tool definition map for the LLM prompt
  - `run/1`        — executes the tool with a map of args, returns any term
  """

  @doc "Unique tool name (snake_case string)."
  @callback name() :: String.t()

  @doc "Full tool definition map passed to the LLM (name, description, parameters)."
  @callback definition() :: map()

  @doc "Execute the tool with the given arguments map."
  @callback run(args :: map()) :: any()
end
