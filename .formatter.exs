# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  export: [
    locals_without_parens: [
      # Cucumberex.DSL
      given_: 2,
      when_: 2,
      then_: 2,
      step: 2,
      world_module: 1,
      parameter_type: 3,
      # Cucumberex.Hooks.DSL
      before_: 1,
      before_: 2,
      after_: 1,
      after_: 2,
      around_: 1,
      around_: 2,
      before_step_: 1,
      after_step_: 1,
      before_all_: 1,
      after_all_: 1,
      install_plugin_: 1
    ]
  ]
]
