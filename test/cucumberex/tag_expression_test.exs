defmodule Cucumberex.Filter.TagExpressionTest do
  use ExUnit.Case, async: true

  alias Cucumberex.Filter.TagExpression

  test "single tag match" do
    assert TagExpression.evaluate("@smoke", ["@smoke", "@fast"])
    refute TagExpression.evaluate("@smoke", ["@fast"])
  end

  test "AND expression" do
    assert TagExpression.evaluate("@smoke and @fast", ["@smoke", "@fast"])
    refute TagExpression.evaluate("@smoke and @fast", ["@smoke"])
  end

  test "OR expression" do
    assert TagExpression.evaluate("@smoke or @fast", ["@fast"])
    assert TagExpression.evaluate("@smoke or @fast", ["@smoke"])
    refute TagExpression.evaluate("@smoke or @fast", ["@slow"])
  end

  test "NOT expression" do
    assert TagExpression.evaluate("not @slow", ["@smoke"])
    refute TagExpression.evaluate("not @slow", ["@slow"])
  end

  test "complex expression" do
    assert TagExpression.evaluate("(@smoke or @fast) and not @skip", ["@smoke"])
    refute TagExpression.evaluate("(@smoke or @fast) and not @skip", ["@smoke", "@skip"])
    refute TagExpression.evaluate("(@smoke or @fast) and not @skip", ["@slow"])
  end

  test "nil tag expression always matches" do
    assert TagExpression.evaluate(nil, [])
    assert TagExpression.evaluate(nil, ["@anything"])
  end

  test "case insensitive tags" do
    assert TagExpression.evaluate("@Smoke", ["@smoke"])
    assert TagExpression.evaluate("@smoke", ["@Smoke"])
  end
end
