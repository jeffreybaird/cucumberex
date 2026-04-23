defmodule DataTableSteps do
  use Cucumberex.DSL

  given_ "the following users:", fn world, table ->
    users = Cucumberex.DataTable.hashes(table)
    Map.put(world, :users, users)
  end

  then_ "there should be {int} users", fn world, count ->
    actual = length(Map.get(world, :users, []))
    unless actual == count do
      raise "Expected #{count} users but got #{actual}"
    end
    world
  end

  given_ "a blog post with content:", fn world, doc ->
    Map.put(world, :post_content, to_string(doc))
  end

  then_ "the post should have content {string}", fn world, expected ->
    content = Map.get(world, :post_content, "")
    unless String.contains?(content, expected) do
      raise "Expected post to contain '#{expected}' but got: #{content}"
    end
    world
  end
end
