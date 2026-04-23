defmodule BellySteps do
  use Cucumberex.DSL

  given_ "I am hungry", fn world ->
    Map.put(world, :hungry, true)
  end

  given_ "I have {int} cukes in my belly", fn world, count ->
    Map.put(world, :cukes, count)
  end

  when_ "I eat {int} cukes", fn world, count ->
    Map.update(world, :cukes, 0, &(&1 - count))
  end

  then_ "I should have {int} cukes remaining", fn world, expected ->
    actual = Map.get(world, :cukes, 0)
    unless actual == expected do
      raise "Expected #{expected} cukes remaining but got #{actual}"
    end
    world
  end
end
