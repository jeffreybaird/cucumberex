defmodule SharedSteps do
  use Cucumberex.DSL

  step "a passing step", fn world -> world end

  step "a pending step", fn world ->
    pending()
    world
  end

  step "a failing step", fn _world ->
    raise "This step intentionally fails"
  end
end
