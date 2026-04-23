defmodule Cucumberex.ParameterType do
  @moduledoc "A named parameter type with a regexp and transformer."

  defstruct [
    :name,
    :regexp,
    :transformer,
    :description,
    use_for_snippets: true,
    prefer_for_regexp_match: false
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          regexp: Regex.t() | [Regex.t()],
          transformer: (list() -> any()),
          description: String.t() | nil,
          use_for_snippets: boolean(),
          prefer_for_regexp_match: boolean()
        }

  @doc """
  Build a `ParameterType` struct.

  ## Examples

      iex> pt = Cucumberex.ParameterType.new("int", ~r/\\d+/, fn [s] -> String.to_integer(s) end)
      iex> pt.name
      "int"
      iex> pt.use_for_snippets
      true

      iex> pt = Cucumberex.ParameterType.new("x", ~r/x/, fn _ -> nil end, use_for_snippets: false)
      iex> pt.use_for_snippets
      false
  """
  def new(name, regexp, transformer, opts \\ []) do
    %__MODULE__{
      name: name,
      regexp: regexp,
      transformer: transformer,
      description: Keyword.get(opts, :description),
      use_for_snippets: Keyword.get(opts, :use_for_snippets, true),
      prefer_for_regexp_match: Keyword.get(opts, :prefer_for_regexp_match, false)
    }
  end

  @doc """
  Apply the parameter type's transformer to a list of captures.

  ## Examples

      iex> pt = Cucumberex.ParameterType.new("int", ~r/\\d+/, fn [s] -> String.to_integer(s) end)
      iex> Cucumberex.ParameterType.transform(pt, ["42"])
      42
  """
  def transform(%__MODULE__{transformer: t}, captures) do
    t.(captures)
  end
end
