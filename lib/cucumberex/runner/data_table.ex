defmodule Cucumberex.DataTable do
  @moduledoc """
  Wrapper around Cucumber pickle table data with convenience accessors.

  Methods mirror cucumber-ruby's DataTable:
    raw/1           — [[cell, ...], ...]
    hashes/1        — [%{header => value}, ...]
    rows/1          — rows without header
    rows_hash/1     — first column as key, second as value
    transpose/1     — swap rows/columns
    map_headers/2   — rename headers
    diff!/2         — compare two tables (raises on mismatch)
  """

  defstruct [:rows]

  @type t :: %__MODULE__{rows: [[String.t()]]}

  @doc """
  Wrap a list of rows in a DataTable.

  ## Examples

      iex> Cucumberex.DataTable.new([["a", "b"], ["1", "2"]]).rows
      [["a", "b"], ["1", "2"]]
  """
  def new(rows) when is_list(rows) do
    %__MODULE__{rows: rows}
  end

  @doc false
  def from_pickle_table(%{rows: rows}) do
    cells = Enum.map(rows, fn row -> Enum.map(row.cells, & &1.value) end)
    new(cells)
  end

  @doc """
  Return the raw rows list.

  ## Examples

      iex> Cucumberex.DataTable.new([["a"], ["1"]]) |> Cucumberex.DataTable.raw()
      [["a"], ["1"]]
  """
  def raw(%__MODULE__{rows: rows}), do: rows

  @doc """
  Treat the first row as headers and return each subsequent row as a map.

  ## Examples

      iex> Cucumberex.DataTable.new([["name", "age"], ["alice", "30"]])
      ...> |> Cucumberex.DataTable.hashes()
      [%{"name" => "alice", "age" => "30"}]

      iex> Cucumberex.DataTable.new([]) |> Cucumberex.DataTable.hashes()
      []
  """
  def hashes(%__MODULE__{rows: [headers | data_rows]}) do
    Enum.map(data_rows, fn row ->
      headers
      |> Enum.zip(row)
      |> Map.new()
    end)
  end

  def hashes(%__MODULE__{rows: []}), do: []

  @doc """
  Return rows without the header.

  ## Examples

      iex> Cucumberex.DataTable.new([["h"], ["1"], ["2"]]) |> Cucumberex.DataTable.rows()
      [["1"], ["2"]]

      iex> Cucumberex.DataTable.new([]) |> Cucumberex.DataTable.rows()
      []
  """
  def rows(%__MODULE__{rows: [_headers | data]}), do: data
  def rows(%__MODULE__{rows: []}), do: []

  @doc """
  Treat each row as a key/value pair (first column = key, second = value).

  ## Examples

      iex> Cucumberex.DataTable.new([["name", "alice"], ["age", "30"]])
      ...> |> Cucumberex.DataTable.rows_hash()
      %{"name" => "alice", "age" => "30"}
  """
  def rows_hash(%__MODULE__{rows: rows}) do
    Enum.reduce(rows, %{}, fn
      [key, value | _], acc -> Map.put(acc, key, value)
      _, acc -> acc
    end)
  end

  @doc """
  Like `hashes/1` but converts header keys to atoms.

  Only call this when headers are known, bounded values (e.g. fixture table headers
  that match struct fields). Avoid with arbitrary user-supplied table headers —
  use `hashes/1` instead to prevent unbounded atom creation.

  ## Examples

      iex> Cucumberex.DataTable.new([["name"], ["alice"]])
      ...> |> Cucumberex.DataTable.symbolic_hashes()
      [%{name: "alice"}]
  """
  def symbolic_hashes(%__MODULE__{} = dt) do
    dt
    |> hashes()
    |> Enum.map(fn row ->
      Map.new(row, fn {k, v} -> {String.to_atom(k), v} end)
    end)
  end

  @doc """
  Swap rows and columns.

  ## Examples

      iex> Cucumberex.DataTable.new([["a", "b"], ["1", "2"]])
      ...> |> Cucumberex.DataTable.transpose()
      ...> |> Cucumberex.DataTable.raw()
      [["a", "1"], ["b", "2"]]
  """
  def transpose(%__MODULE__{rows: rows}) do
    new(rows |> Enum.zip() |> Enum.map(&Tuple.to_list/1))
  end

  @doc """
  Rename headers using a map of old -> new or a 1-arity function.

  ## Examples

      iex> Cucumberex.DataTable.new([["full name"], ["alice"]])
      ...> |> Cucumberex.DataTable.map_headers(%{"full name" => "name"})
      ...> |> Cucumberex.DataTable.raw()
      [["name"], ["alice"]]

      iex> Cucumberex.DataTable.new([["name"], ["alice"]])
      ...> |> Cucumberex.DataTable.map_headers(&String.upcase/1)
      ...> |> Cucumberex.DataTable.raw()
      [["NAME"], ["alice"]]
  """
  def map_headers(%__MODULE__{rows: [headers | rest]}, mapping) when is_map(mapping) do
    new_headers = Enum.map(headers, fn h -> Map.get(mapping, h, h) end)
    new([new_headers | rest])
  end

  def map_headers(%__MODULE__{} = dt, fun) when is_function(fun, 1) do
    %{
      dt
      | rows:
          case dt.rows do
            [] -> []
            [headers | rest] -> [Enum.map(headers, fun) | rest]
          end
    }
  end

  @doc """
  Apply a transform function to every value in a named column.

  ## Examples

      iex> Cucumberex.DataTable.new([["n", "v"], ["a", "1"], ["b", "2"]])
      ...> |> Cucumberex.DataTable.map_column("v", &String.to_integer/1)
      ...> |> Cucumberex.DataTable.raw()
      [["n", "v"], ["a", 1], ["b", 2]]
  """
  def map_column(%__MODULE__{rows: [headers | rest]}, col_name, fun) do
    col_idx = Enum.find_index(headers, &(&1 == col_name))

    if col_idx do
      new_rest =
        Enum.map(rest, fn row ->
          List.update_at(row, col_idx, fun)
        end)

      new([headers | new_rest])
    else
      raise "Column #{col_name} not found in #{inspect(headers)}"
    end
  end

  @doc """
  Compare two tables; raise if rows differ, return `:ok` otherwise.

  ## Examples

      iex> a = Cucumberex.DataTable.new([["h"], ["1"]])
      iex> Cucumberex.DataTable.diff!(a, a)
      :ok
  """
  def diff!(%__MODULE__{rows: a}, %__MODULE__{rows: b}) do
    if a != b do
      raise """
      Tables differ:
      Expected:
      #{format_table(a)}
      Got:
      #{format_table(b)}
      """
    end

    :ok
  end

  @doc """
  Raise if `col_name` is not among the header row; return `:ok` otherwise.

  ## Examples

      iex> Cucumberex.DataTable.new([["name", "age"]]) |> Cucumberex.DataTable.verify_column!("name")
      :ok
  """
  def verify_column!(%__MODULE__{rows: [headers | _]}, col_name) do
    if col_name in headers do
      :ok
    else
      raise "Expected column #{col_name} but got #{inspect(headers)}"
    end
  end

  @doc """
  Raise if any row's length differs from `width`; return `:ok` otherwise.

  ## Examples

      iex> Cucumberex.DataTable.new([["a", "b"], ["1", "2"]])
      ...> |> Cucumberex.DataTable.verify_table_width!(2)
      :ok
  """
  def verify_table_width!(%__MODULE__{rows: rows}, width) do
    Enum.each(rows, fn row ->
      if length(row) != width do
        raise "Expected row width #{width}, got #{length(row)}: #{inspect(row)}"
      end
    end)
  end

  defp format_table(rows) do
    Enum.map_join(rows, "\n", fn row -> "  | " <> Enum.join(row, " | ") <> " |" end)
  end
end

defmodule Cucumberex.DocString do
  @moduledoc "Multi-line doc string argument in a step."

  defstruct [:content, :content_type, :delimiter]

  @type t :: %__MODULE__{
          content: String.t(),
          content_type: String.t() | nil,
          delimiter: String.t()
        }

  @doc """
  Build a DocString struct.

  ## Examples

      iex> Cucumberex.DocString.new("hello").content
      "hello"

      iex> Cucumberex.DocString.new("x", "text/plain").content_type
      "text/plain"
  """
  def new(content, content_type \\ nil, delimiter \\ ~s(""")) do
    %__MODULE__{content: content, content_type: content_type, delimiter: delimiter}
  end

  @doc false
  def from_pickle_doc_string(%{content: content, media_type: mt}) do
    new(content, if(mt == "", do: nil, else: mt))
  end

  defimpl String.Chars do
    def to_string(%{content: c}), do: c
  end
end
