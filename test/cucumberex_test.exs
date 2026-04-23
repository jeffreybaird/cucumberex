defmodule CucumberexTest do
  use ExUnit.Case

  doctest Cucumberex
  doctest Cucumberex.Config
  doctest Cucumberex.Config.Loader
  doctest Cucumberex.DataTable
  doctest Cucumberex.DocString
  doctest Cucumberex.Filter.LineFilter
  doctest Cucumberex.Filter.NameFilter
  doctest Cucumberex.Filter.TagExpression
  doctest Cucumberex.Formatter.ANSI
  doctest Cucumberex.Hook
  doctest Cucumberex.ParameterType
  doctest Cucumberex.ParameterType.BuiltIn
  doctest Cucumberex.Result
  doctest Cucumberex.StepDefinition
  doctest Cucumberex.StepDefinition.Expression
  doctest Cucumberex.StepDefinition.Snippet
  doctest Cucumberex.World

  test "version is a string" do
    assert is_binary(Cucumberex.version())
  end
end
