defmodule Clawixir.Skills.BuiltIn.Weather do
  @moduledoc "Built-in weather skill using Open-Meteo (free, no API key needed)."
  @behaviour Clawixir.Skills.Skill

  @impl true
  def name, do: "get_weather"

  @impl true
  def definition do
    %{
      name: name(),
      description: "Get the current weather for a given city or location.",
      parameters: %{
        type: "object",
        properties: %{
          location: %{type: "string", description: "City name or location, e.g. 'Berlin'"}
        },
        required: ["location"]
      }
    }
  end

  @impl true
  def run(%{"location" => location}) do
    with {:ok, coords} <- geocode(location),
         {:ok, weather} <- fetch_weather(coords) do
      weather
    else
      {:error, reason} -> %{error: "Could not fetch weather: #{inspect(reason)}"}
    end
  end

  defp geocode(location) do
    url = "https://geocoding-api.open-meteo.com/v1/search"

    case Req.get(url, params: [name: location, count: 1, format: "json"]) do
      {:ok, %{status: 200, body: %{"results" => [r | _]}}} ->
        {:ok, %{lat: r["latitude"], lon: r["longitude"], name: r["name"], country: r["country"]}}

      {:ok, %{body: %{"results" => []}}} ->
        {:error, :location_not_found}

      {:error, _} = err ->
        err
    end
  end

  defp fetch_weather(%{lat: lat, lon: lon, name: name, country: country}) do
    url = "https://api.open-meteo.com/v1/forecast"
    params = [
      latitude: lat,
      longitude: lon,
      current: "temperature_2m,weathercode,windspeed_10m,relativehumidity_2m",
      timezone: "auto"
    ]

    case Req.get(url, params: params) do
      {:ok, %{status: 200, body: %{"current" => curr}}} ->
        {:ok, %{
          location: "#{name}, #{country}",
          temperature_c: curr["temperature_2m"],
          wind_kmh: curr["windspeed_10m"],
          humidity_pct: curr["relativehumidity_2m"],
          condition: weather_code(curr["weathercode"])
        }}

      err ->
        {:error, err}
    end
  end

  defp weather_code(code) do
    case code do
      0  -> "Clear sky"
      c when c in 1..3   -> "Partly cloudy"
      c when c in 45..48 -> "Foggy"
      c when c in 51..67 -> "Drizzle or rain"
      c when c in 71..77 -> "Snow"
      c when c in 80..82 -> "Rain showers"
      c when c in 95..99 -> "Thunderstorm"
      _  -> "Unknown"
    end
  end
end
