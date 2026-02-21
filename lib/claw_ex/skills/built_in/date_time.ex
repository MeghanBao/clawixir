defmodule Clawixir.Skills.BuiltIn.DateTime do
  @moduledoc "Returns the current date and time for a given timezone."
  @behaviour Clawixir.Skills.Skill

  @impl true
  def name, do: "get_datetime"

  @impl true
  def definition do
    %{
      name: name(),
      description: "Get the current date and time, optionally in a specific timezone.",
      parameters: %{
        type: "object",
        properties: %{
          timezone: %{
            type: "string",
            description: "IANA timezone name, e.g. 'Europe/Berlin'. Defaults to UTC."
          }
        },
        required: []
      }
    }
  end

  @impl true
  def run(args) do
    tz = Map.get(args, "timezone", "UTC")
    now = DateTime.utc_now()

    %{
      utc:      DateTime.to_string(now),
      timezone: tz,
      note:     "Full timezone conversion requires the `tz` Elixir library; currently returning UTC."
    }
  end
end
