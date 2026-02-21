defmodule Clawixir.Agent.ToolRegistryTest do
  use ExUnit.Case

  alias Clawixir.Agent.ToolRegistry

  # ToolRegistry is started by the application supervisor and
  # auto-registers built-in skills. Tests validate that state.

  describe "all_tools/0" do
    test "returns a list of tool definitions" do
      tools = ToolRegistry.all_tools()
      assert is_list(tools)
      assert length(tools) >= 6  # 6 built-in skills
    end

    test "each tool has name, description, and parameters" do
      for tool <- ToolRegistry.all_tools() do
        assert Map.has_key?(tool, :name), "Tool missing :name"
        assert Map.has_key?(tool, :description), "Tool #{tool[:name]} missing :description"
        assert Map.has_key?(tool, :parameters), "Tool #{tool[:name]} missing :parameters"
      end
    end

    test "includes the calculate tool" do
      names = Enum.map(ToolRegistry.all_tools(), & &1.name)
      assert "calculate" in names
    end
  end

  describe "invoke/2" do
    test "invokes the calculate tool correctly" do
      result = ToolRegistry.invoke("calculate", %{"expression" => "1 + 1"})
      assert %{result: 2.0} = result
    end

    test "returns error for unknown tool" do
      result = ToolRegistry.invoke("nonexistent_tool", %{})
      assert %{error: _} = result
    end
  end

  describe "register/1" do
    test "dynamically registers a new tool" do
      defmodule TestSkill do
        @behaviour Clawixir.Skills.Skill

        def name, do: "test_skill_#{:erlang.unique_integer([:positive])}"

        def definition do
          %{name: name(), description: "A test skill", parameters: %{type: "object", properties: %{}, required: []}}
        end

        def run(_args), do: %{ok: true}
      end

      ToolRegistry.register(TestSkill)
      # Give the GenServer a moment to process the cast
      Process.sleep(50)

      names = Enum.map(ToolRegistry.all_tools(), & &1.name)
      assert TestSkill.name() in names
    end
  end
end
