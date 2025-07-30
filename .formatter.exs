[
  inputs: [
    ".credo.exs",
    ".formatter.exs",
    "apps/*/mix.exs",
    "apps/*/{benchmarks,config,lib,priv,test}/**/*.{ex,exs}",
    "mix.exs",
    "{config}/**/*.{ex,exs}"
  ],
  line_length: 120,
  import_deps: [:open_api_spex]
]
