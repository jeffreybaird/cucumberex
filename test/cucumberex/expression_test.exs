defmodule Cucumberex.StepDefinition.ExpressionTest do
  use ExUnit.Case, async: true

  alias Cucumberex.StepDefinition.Expression

  describe "Cucumber Expressions" do
    test "literal match" do
      assert %{args: []} = Expression.match("I have a cucumber", "I have a cucumber")
      assert nil == Expression.match("I have a cucumber", "I have a carrot")
    end

    test "{int} parameter" do
      result = Expression.match("I have {int} cukes", "I have 5 cukes")
      assert %{args: [5]} = result
    end

    test "negative {int}" do
      result = Expression.match("temperature is {int} degrees", "temperature is -10 degrees")
      assert %{args: [-10]} = result
    end

    test "{float} parameter" do
      result = Expression.match("price is {float}", "price is 9.99")
      assert %{args: [9.99]} = result
    end

    test "{word} parameter" do
      result = Expression.match("I am {word}", "I am happy")
      assert %{args: ["happy"]} = result
    end

    test "{string} parameter with double quotes" do
      result = Expression.match("I say {string}", ~s(I say "hello world"))
      assert %{args: [_]} = result
    end

    test "multiple parameters" do
      result =
        Expression.match("I have {int} {word} and {int} {word}", "I have 3 apples and 2 oranges")

      assert %{args: [3, "apples", 2, "oranges"]} = result
    end

    test "optional text" do
      assert %{args: []} = Expression.match("I eat(s) food", "I eat food")
      assert %{args: []} = Expression.match("I eat(s) food", "I eats food")
    end

    test "regex pattern still works" do
      assert %{args: ["5"]} = Expression.match(~r/I have (\d+) cukes/, "I have 5 cukes")
      assert nil == Expression.match(~r/I have (\d+) cukes/, "I have no cukes")
    end
  end
end
