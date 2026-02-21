defmodule Clawixir.Skills.BuiltIn.CalculatorTest do
  use ExUnit.Case, async: true

  alias Clawixir.Skills.BuiltIn.Calculator

  describe "name/0" do
    test "returns calculate" do
      assert Calculator.name() == "calculate"
    end
  end

  describe "definition/0" do
    test "returns a valid tool definition map" do
      defn = Calculator.definition()
      assert defn.name == "calculate"
      assert is_binary(defn.description)
      assert defn.parameters.type == "object"
      assert Map.has_key?(defn.parameters.properties, :expression)
    end
  end

  describe "run/1" do
    test "basic addition" do
      assert %{result: 5.0} = Calculator.run(%{"expression" => "2 + 3"})
    end

    test "basic subtraction" do
      assert %{result: 7.0} = Calculator.run(%{"expression" => "10 - 3"})
    end

    test "multiplication" do
      assert %{result: 12.0} = Calculator.run(%{"expression" => "3 * 4"})
    end

    test "division" do
      assert %{result: 2.5} = Calculator.run(%{"expression" => "5 / 2"})
    end

    test "parentheses change precedence" do
      assert %{result: 20.0} = Calculator.run(%{"expression" => "(2 + 3) * 4"})
    end

    test "operator precedence without parentheses" do
      assert %{result: 14.0} = Calculator.run(%{"expression" => "2 + 3 * 4"})
    end

    test "power operator" do
      assert %{result: 8.0} = Calculator.run(%{"expression" => "2 ** 3"})
    end

    test "negative numbers" do
      assert %{result: -5.0} = Calculator.run(%{"expression" => "-5"})
    end

    test "nested parentheses" do
      assert %{result: 9.0} = Calculator.run(%{"expression" => "(1 + 2) * (1 + 2)"})
    end

    test "decimal numbers" do
      assert %{result: result} = Calculator.run(%{"expression" => "1.5 + 2.5"})
      assert_in_delta result, 4.0, 0.001
    end

    test "invalid expression returns error" do
      assert %{error: _msg} = Calculator.run(%{"expression" => "abc"})
    end

    test "empty expression returns error" do
      assert %{error: _msg} = Calculator.run(%{"expression" => ""})
    end
  end
end
