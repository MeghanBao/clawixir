defmodule Clawixir.Agent.ToolRegistry do
  @moduledoc """
  GenServer that maintains the catalogue of available tools/skills.

  Tools are registered as modules implementing the `Clawixir.Skills.Skill` behaviour.
  Built-in tools are auto-registered at startup.

  ## Usage

      # Get all tool definitions for LLM context
      Clawixir.Agent.ToolRegistry.all_tools()

      # Invoke a tool by name
      Clawixir.Agent.ToolRegistry.invoke("get_weather", %{"location" => "Berlin"})

      # Register a custom tool at runtime
      Clawixir.Agent.ToolRegistry.register(MyApp.Tools.Calculator)
  """

  use GenServer
  require Logger

  alias Clawixir.Skills.BuiltIn

  @name __MODULE__

  # Default built-in skill modules
  @default_skills [
    BuiltIn.Weather,
    BuiltIn.WebSearch,
    BuiltIn.DateTime,
    BuiltIn.Calculator,
    BuiltIn.BrowserControl,
    BuiltIn.RagQuery
  ]

  # ─── Public API ────────────────────────────────────────────────────────────

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: @name)

  @doc "Return all tool definitions as a list of maps for the LLM."
  @spec all_tools() :: [map()]
  def all_tools, do: GenServer.call(@name, :all_tools)

  @doc "Invoke a tool by name with a map of arguments. Returns the result."
  @spec invoke(String.t(), map()) :: any()
  def invoke(name, args), do: GenServer.call(@name, {:invoke, name, args})

  @doc "Register an additional skill module at runtime."
  @spec register(module()) :: :ok
  def register(mod), do: GenServer.cast(@name, {:register, mod})

  # ─── GenServer callbacks ────────────────────────────────────────────────────

  @impl true
  def init(_) do
    tools_map =
      @default_skills
      |> Enum.map(fn mod -> {mod.name(), mod} end)
      |> Map.new()

    Logger.info("[ToolRegistry] registered #{map_size(tools_map)} built-in tools")
    {:ok, tools_map}
  end

  @impl true
  def handle_call(:all_tools, _from, tools_map) do
    defs = Enum.map(tools_map, fn {_name, mod} -> mod.definition() end)
    {:reply, defs, tools_map}
  end

  @impl true
  def handle_call({:invoke, name, args}, _from, tools_map) do
    result =
      case Map.fetch(tools_map, name) do
        {:ok, mod} ->
          Logger.info("[ToolRegistry] invoking #{name} with #{inspect(args)}")
          mod.run(args)

        :error ->
          %{error: "Unknown tool: #{name}"}
      end

    {:reply, result, tools_map}
  end

  @impl true
  def handle_cast({:register, mod}, tools_map) do
    Logger.info("[ToolRegistry] registering dynamic tool: #{mod.name()}")
    {:noreply, Map.put(tools_map, mod.name(), mod)}
  end
end
