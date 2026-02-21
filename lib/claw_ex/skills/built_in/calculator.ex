defmodule Clawixir.Skills.BuiltIn.Calculator do
  @moduledoc "Safe arithmetic evaluator for basic math expressions."
  @behaviour Clawixir.Skills.Skill

  @impl true
  def name, do: "calculate"

  @impl true
  def definition do
    %{
      name: name(),
      description: "Evaluate a basic math expression and return the result. Supports +, -, *, /, ** (power), and parentheses.",
      parameters: %{
        type: "object",
        properties: %{
          expression: %{type: "string", description: "Math expression, e.g. '(2 + 3) * 4'"}
        },
        required: ["expression"]
      }
    }
  end

  @impl true
  def run(%{"expression" => expr}) do
    case safe_eval(expr) do
      {:ok, result}  -> %{expression: expr, result: result}
      {:error, msg}  -> %{error: msg}
    end
  end

  # Tokenize & evaluate a safe arithmetic expression (no Code.eval_string!)
  defp safe_eval(expr) do
    tokens = tokenize(String.trim(expr))
    case parse_expr(tokens) do
      {result, []} -> {:ok, result}
      {_, rest}    -> {:error, "Unexpected tokens: #{inspect(rest)}"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  # ─── Recursive descent parser ───────────────────────────────────────────────

  defp tokenize(expr) do
    ~r/(\d+\.?\d*|\+|\-|\*{1,2}|\/|\(|\))/
    |> Regex.scan(expr)
    |> Enum.map(fn [token, _] -> token end)
  end

  defp parse_expr(tokens), do: parse_add(tokens)

  defp parse_add(tokens) do
    {left, rest} = parse_mul(tokens)
    parse_add_tail(left, rest)
  end

  defp parse_add_tail(left, ["+" | rest]) do
    {right, rest2} = parse_mul(rest)
    parse_add_tail(left + right, rest2)
  end
  defp parse_add_tail(left, ["-" | rest]) do
    {right, rest2} = parse_mul(rest)
    parse_add_tail(left - right, rest2)
  end
  defp parse_add_tail(left, rest), do: {left, rest}

  defp parse_mul(tokens) do
    {left, rest} = parse_pow(tokens)
    parse_mul_tail(left, rest)
  end

  defp parse_mul_tail(left, ["*" | rest]) do
    {right, rest2} = parse_pow(rest)
    parse_mul_tail(left * right, rest2)
  end
  defp parse_mul_tail(left, ["/" | rest]) do
    {right, rest2} = parse_pow(rest)
    parse_mul_tail(left / right, rest2)
  end
  defp parse_mul_tail(left, rest), do: {left, rest}

  defp parse_pow(tokens) do
    {base, rest} = parse_unary(tokens)
    case rest do
      ["**" | rest2] ->
        {exp, rest3} = parse_unary(rest2)
        {Float.pow(base * 1.0, exp * 1.0), rest3}
      _ ->
        {base, rest}
    end
  end

  defp parse_unary(["-" | rest]) do
    {val, rest2} = parse_primary(rest)
    {-val, rest2}
  end
  defp parse_unary(tokens), do: parse_primary(tokens)

  defp parse_primary(["(" | rest]) do
    {val, rest2} = parse_expr(rest)
    case rest2 do
      [")" | rest3] -> {val, rest3}
      _ -> raise "Expected closing parenthesis"
    end
  end
  defp parse_primary([token | rest]) do
    case Float.parse(token) do
      {num, ""} -> {num, rest}
      _         -> raise "Unexpected token: #{token}"
    end
  end
  defp parse_primary([]), do: raise("Unexpected end of expression")
end
