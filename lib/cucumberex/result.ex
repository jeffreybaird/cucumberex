defmodule Cucumberex.Result do
  @moduledoc "Step and scenario result types."

  @type status :: :passed | :failed | :pending | :undefined | :skipped | :ambiguous | :flaky

  defstruct [:status, :error, :duration_ms]

  @type t :: %__MODULE__{
          status: status(),
          error: Exception.t() | nil,
          duration_ms: non_neg_integer() | nil
        }

  @doc """
  Returns a passed result.

      iex> Cucumberex.Result.passed().status
      :passed
      iex> Cucumberex.Result.passed(100).duration_ms
      100
  """
  def passed(duration_ms \\ nil), do: %__MODULE__{status: :passed, duration_ms: duration_ms}

  @doc """
  Returns a failed result wrapping an error.

      iex> r = Cucumberex.Result.failed(%RuntimeError{message: "oops"})
      iex> r.status
      :failed
  """
  def failed(error, duration_ms \\ nil),
    do: %__MODULE__{status: :failed, error: error, duration_ms: duration_ms}

  @doc """
      iex> Cucumberex.Result.pending().status
      :pending
  """
  def pending, do: %__MODULE__{status: :pending}

  @doc """
      iex> Cucumberex.Result.undefined().status
      :undefined
  """
  def undefined, do: %__MODULE__{status: :undefined}

  @doc """
      iex> Cucumberex.Result.skipped().status
      :skipped
  """
  def skipped, do: %__MODULE__{status: :skipped}

  @doc """
      iex> Cucumberex.Result.ambiguous([:a, :b]).status
      :ambiguous
  """
  def ambiguous(matches), do: %__MODULE__{status: :ambiguous, error: {:ambiguous, matches}}

  @doc """
      iex> Cucumberex.Result.flaky().status
      :flaky
  """
  def flaky, do: %__MODULE__{status: :flaky}

  @doc """
      iex> Cucumberex.Result.passed?(%Cucumberex.Result{status: :passed})
      true
      iex> Cucumberex.Result.passed?(%Cucumberex.Result{status: :failed})
      false
  """
  def passed?(%__MODULE__{status: :passed}), do: true
  def passed?(_), do: false

  @doc """
      iex> Cucumberex.Result.failed?(%Cucumberex.Result{status: :failed})
      true
      iex> Cucumberex.Result.failed?(%Cucumberex.Result{status: :passed})
      false
  """
  def failed?(%__MODULE__{status: :failed}), do: true
  def failed?(_), do: false

  @doc """
      iex> Cucumberex.Result.ok?(%Cucumberex.Result{status: :passed})
      true
      iex> Cucumberex.Result.ok?(%Cucumberex.Result{status: :skipped})
      true
      iex> Cucumberex.Result.ok?(%Cucumberex.Result{status: :failed})
      false
  """
  def ok?(%__MODULE__{status: s}), do: s in [:passed, :skipped]
  def ok?(_), do: false

  @doc """
  Returns the worst result by priority: failed > ambiguous > undefined > pending > flaky > skipped > passed.

      iex> results = [Cucumberex.Result.passed(), Cucumberex.Result.failed(%RuntimeError{})]
      iex> Cucumberex.Result.worst(results).status
      :failed
  """
  def worst(results) when is_list(results) do
    priority = [:failed, :ambiguous, :undefined, :pending, :flaky, :skipped, :passed]
    Enum.min_by(results, fn r -> Enum.find_index(priority, &(&1 == r.status)) || 999 end)
  end

  @doc """
      iex> Cucumberex.Result.to_exit_code([Cucumberex.Result.passed()])
      0
      iex> Cucumberex.Result.to_exit_code([Cucumberex.Result.failed(%RuntimeError{})])
      1
  """
  def to_exit_code(results) when is_list(results) do
    if Enum.all?(results, &passed?/1), do: 0, else: 1
  end
end
