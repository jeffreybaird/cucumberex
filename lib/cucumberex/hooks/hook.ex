defmodule Cucumberex.Hook do
  @moduledoc "A registered hook with phase, tag filter, and implementation."

  alias Cucumberex.Filter.TagExpression

  defstruct [:id, :phase, :tag_expression, :fun, :location, :order]

  @type phase ::
          :before
          | :after
          | :around
          | :before_step
          | :after_step
          | :before_all
          | :after_all
          | :install_plugin

  @type t :: %__MODULE__{
          id: String.t(),
          phase: phase(),
          tag_expression: String.t() | nil,
          fun: function(),
          location: String.t(),
          order: integer()
        }

  @doc """
  Build a `Hook`. A fresh UUID is assigned to `:id` on each call.

  ## Examples

      iex> h = Cucumberex.Hook.new(:before, fn _ -> :ok end, tags: "@smoke")
      iex> {h.phase, h.tag_expression, h.order, h.location}
      {:before, "@smoke", 0, "unknown"}

      iex> h = Cucumberex.Hook.new(:after, fn _ -> :ok end)
      iex> h.tag_expression
      nil
  """
  def new(phase, fun, opts \\ []) do
    %__MODULE__{
      id: UUID.uuid4(),
      phase: phase,
      tag_expression: Keyword.get(opts, :tags),
      fun: fun,
      location: Keyword.get(opts, :location, "unknown"),
      order: Keyword.get(opts, :order, 0)
    }
  end

  @doc """
  Check if a hook should apply to a scenario tagged with the given tags.
  A hook with no tag expression applies to all scenarios.

  ## Examples

      iex> h = %Cucumberex.Hook{tag_expression: nil}
      iex> Cucumberex.Hook.applies_to?(h, ["@any"])
      true

      iex> h = %Cucumberex.Hook{tag_expression: "@smoke"}
      iex> Cucumberex.Hook.applies_to?(h, ["@smoke"])
      true

      iex> h = %Cucumberex.Hook{tag_expression: "@smoke"}
      iex> Cucumberex.Hook.applies_to?(h, ["@other"])
      false
  """
  def applies_to?(%__MODULE__{tag_expression: nil}, _tags), do: true

  def applies_to?(%__MODULE__{tag_expression: expr}, tags) do
    TagExpression.evaluate(expr, tags)
  end
end
