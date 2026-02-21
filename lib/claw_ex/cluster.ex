defmodule Clawixir.Cluster do
  @moduledoc """
  Optional BEAM multi-node clustering via `libcluster`.

  Enabled by setting `CLUSTER_ENABLED=true` in your environment.

  ## How it works

  Uses the **Gossip** topology: nodes discover each other automatically
  via UDP multicast on the local network. No Kubernetes, no Consul,
  no Redis needed — just BEAM primitives.

  When two nodes connect:

  - Sessions are visible across nodes via `Registry` (if distributed)
  - Phoenix PubSub broadcasts across the cluster automatically
  - Presence state is merged across nodes via CRDT

  ## Topologies

  ### Local development (Gossip — LAN multicast)
  ```
  CLUSTER_ENABLED=true
  # Nodes discover each other on the local network automatically
  ```

  ### Production (DNS — for Kubernetes/Fly.io/Render)
  Set `CLUSTER_STRATEGY=dns` and `CLUSTER_DNS_NAME=claw-ex.internal`.

  ## Starting manually in IEx

      iex --sname node1 --cookie secret -S mix phx.server
      iex --sname node2 --cookie secret -S mix phx.server
      # → they find each other within a few seconds

  See `application.ex` for how this module is conditionally added to the
  supervision tree.
  """

  @doc """
  Returns libcluster child spec if clustering is enabled, nil otherwise.
  Call this from `application.ex`.
  """
  def child_spec_if_enabled do
    if Application.get_env(:clawixir, :cluster_enabled, false) do
      strategy  = cluster_strategy()
      topology  = build_topology(strategy)
      {Cluster.Supervisor, [topology, [name: Clawixir.ClusterSupervisor]]}
    else
      nil
    end
  end

  # ─── Internal ───────────────────────────────────────────────────────────────

  defp cluster_strategy do
    case System.get_env("CLUSTER_STRATEGY", "gossip") do
      "dns"    -> :dns
      "epmd"   -> :epmd
      _        -> :gossip
    end
  end

  defp build_topology(:gossip) do
    [
      clawixir: [
        strategy: Cluster.Strategy.Gossip,
        config: [
          port: 45892,
          if_addr: "0.0.0.0",
          multicast_addr: "230.1.1.251",
          multicast_ttl: 1,
          secret: Application.get_env(:clawixir, :cluster_secret, "clawixir_cluster")
        ]
      ]
    ]
  end

  defp build_topology(:dns) do
    dns_name = System.get_env("CLUSTER_DNS_NAME", "claw-ex.internal")
    [
      clawixir: [
        strategy: Cluster.Strategy.DNSPoll,
        config: [query: dns_name, node_basename: "clawixir"]
      ]
    ]
  end

  defp build_topology(:epmd) do
    hosts = System.get_env("CLUSTER_HOSTS", "") |> String.split(",", trim: true)
    [
      clawixir: [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts: Enum.map(hosts, &String.to_atom/1)]
      ]
    ]
  end
end
