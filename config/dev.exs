import Config

config :clawixir, ClawixirWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: false,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_min_64_chars_replace_in_prod_xxxxxxxxxxxxxxxxxxx",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:clawixir, ~w(--sourcemap=inline --watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"lib/claw_ex_web/(live|views|controllers)/.*(ex|heex)$",
      ~r"lib/claw_ex_web/layouts/.*(ex|heex)$",
      ~r"assets/(css|js)/.*$"
    ]
  ]

config :logger, level: :debug
