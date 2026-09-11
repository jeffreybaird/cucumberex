defmodule Cucumberex.Formatter.Output do
  @moduledoc """
  Resolve and write to a streaming formatter's output target.

  Accepts these output specs:

    * `:stdio` or `"-"` - standard output
    * `{:file, path}` or a bare path string - a file, truncated on open
    * a pid - test capture; receives `{:formatter_output, iodata}` messages

  Open a device with `open/1`, write to it with `write/2`, and release it with
  `close/1`. All functions perform I/O, so none carry doctests.
  """

  @type spec :: :stdio | String.t() | {:file, String.t()} | pid()
  @type device :: {:stdio, nil} | {:file, pid()} | {:pid, pid()}

  @doc "Open an output device for the given spec."
  def open(:stdio), do: {:stdio, nil}
  def open("-"), do: {:stdio, nil}
  def open(pid) when is_pid(pid), do: {:pid, pid}
  def open({:file, path}), do: open_file(path)
  def open(path) when is_binary(path), do: open_file(path)

  defp open_file(path) do
    path |> Path.dirname() |> File.mkdir_p!()
    {:ok, io} = File.open(path, [:write, :utf8])
    {:file, io}
  end

  @doc "Write `data` to an opened device."
  def write({:stdio, _}, data), do: IO.write(data)
  def write({:file, io}, data), do: IO.write(io, data)
  def write({:pid, pid}, data), do: send(pid, {:formatter_output, data})

  @doc "Close an opened device. A no-op for stdout and pid targets."
  def close({:file, io}), do: File.close(io)
  def close(_), do: :ok
end
