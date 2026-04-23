defmodule Cucumberex.StepDefinition do
  @moduledoc "A registered step definition with pattern and implementation."

  defstruct [:id, :pattern, :compiled_regex, :fun, :location, :keyword]

  @type t :: %__MODULE__{
          id: String.t(),
          pattern: String.t() | Regex.t(),
          compiled_regex: Regex.t() | nil,
          fun: function(),
          location: String.t(),
          keyword: :given | :when_ | :then | :step
        }

  @doc """
  Build a `StepDefinition`. A fresh UUID is assigned to `:id` on each call.

  ## Examples

      iex> sd = Cucumberex.StepDefinition.new("I have {int} cukes", fn _, _ -> :ok end, "t.ex:1", :given)
      iex> {sd.pattern, sd.keyword, sd.location}
      {"I have {int} cukes", :given, "t.ex:1"}

      iex> sd = Cucumberex.StepDefinition.new(~r/^x$/, fn _, _ -> :ok end, "t.ex:1")
      iex> sd.keyword
      :step
  """
  def new(pattern, fun, location, keyword \\ :step) do
    %__MODULE__{
      id: UUID.uuid4(),
      pattern: pattern,
      compiled_regex: nil,
      fun: fun,
      location: location,
      keyword: keyword
    }
  end
end
