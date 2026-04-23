defmodule Cucumberex.DataTableTest do
  use ExUnit.Case, async: true

  alias Cucumberex.DataTable

  @table DataTable.new([
           ["name", "email"],
           ["Alice", "alice@test.com"],
           ["Bob", "bob@test.com"]
         ])

  test "raw/1 returns all rows" do
    assert DataTable.raw(@table) == [
             ["name", "email"],
             ["Alice", "alice@test.com"],
             ["Bob", "bob@test.com"]
           ]
  end

  test "hashes/1 returns header-keyed maps" do
    assert DataTable.hashes(@table) == [
             %{"name" => "Alice", "email" => "alice@test.com"},
             %{"name" => "Bob", "email" => "bob@test.com"}
           ]
  end

  test "rows/1 returns data rows without header" do
    assert DataTable.rows(@table) == [
             ["Alice", "alice@test.com"],
             ["Bob", "bob@test.com"]
           ]
  end

  test "symbolic_hashes/1 returns atom-keyed maps" do
    hashes = DataTable.symbolic_hashes(@table)
    assert [%{name: "Alice"}, %{name: "Bob"}] = hashes
  end

  test "rows_hash/1 maps first col to second" do
    table = DataTable.new([["key1", "val1"], ["key2", "val2"]])
    assert DataTable.rows_hash(table) == %{"key1" => "val1", "key2" => "val2"}
  end

  test "transpose/1 swaps rows and columns" do
    t = DataTable.new([["a", "b"], ["1", "2"]])
    assert DataTable.raw(DataTable.transpose(t)) == [["a", "1"], ["b", "2"]]
  end

  test "map_headers/2 renames columns" do
    mapped = DataTable.map_headers(@table, %{"name" => "full_name"})
    hashes = DataTable.hashes(mapped)
    assert hashes |> hd() |> Map.has_key?("full_name")
    refute hashes |> hd() |> Map.has_key?("name")
  end

  test "diff!/2 passes for identical tables" do
    t2 = DataTable.new(DataTable.raw(@table))
    assert DataTable.diff!(@table, t2) == :ok
  end

  test "diff!/2 raises for different tables" do
    t2 = DataTable.new([["a"], ["b"]])
    assert_raise RuntimeError, fn -> DataTable.diff!(@table, t2) end
  end
end
