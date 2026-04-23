defmodule Cucumberex.DSL do
  @moduledoc """
  Step definition DSL.

  ## Usage

      defmodule MySteps do
        use Cucumberex.DSL

        given_ "I have {int} cukes in my belly", fn world, count ->
          Map.put(world, :cukes, count)
        end

        when_ ~r/I eat (\\d+) cukes/, fn world, count_str ->
          count = String.to_integer(count_str)
          Map.update(world, :cukes, 0, &(&1 - count))
        end

        then_ "I should have {int} cukes", fn world, expected ->
          if world.cukes != expected do
            raise "Expected \#{expected} cukes, got \#{world.cukes}"
          end
          world
        end
      end

  Step functions: `fn world, arg1, arg2, ... -> new_world end`
  Call `pending()` inside to mark a step pending.
  """

  defmacro __using__(_opts) do
    quote do
      import Cucumberex.DSL,
        only: [
          given_: 2,
          when_: 2,
          then_: 2,
          step: 2,
          pending: 0,
          world_module: 1,
          parameter_type: 3
        ]

      Module.register_attribute(__MODULE__, :__cucumberex_steps__, accumulate: true)
      Module.register_attribute(__MODULE__, :__cucumberex_world_modules__, accumulate: true)
      Module.register_attribute(__MODULE__, :__cucumberex_param_types__, accumulate: true)
      @before_compile Cucumberex.DSL
    end
  end

  defmacro __before_compile__(env) do
    steps = env.module |> Module.get_attribute(:__cucumberex_steps__, []) |> Enum.reverse()
    world_modules = Module.get_attribute(env.module, :__cucumberex_world_modules__, [])
    param_types = Module.get_attribute(env.module, :__cucumberex_param_types__, [])

    quote do
      def __cucumberex_steps__, do: unquote(Macro.escape(steps))
      def __cucumberex_world_modules__, do: unquote(Macro.escape(world_modules))
      def __cucumberex_param_types__, do: unquote(Macro.escape(param_types))
    end
  end

  defmacro given_(pattern, fun_ast), do: do_step(pattern, fun_ast, :given, __CALLER__)
  defmacro when_(pattern, fun_ast), do: do_step(pattern, fun_ast, :when_, __CALLER__)
  defmacro then_(pattern, fun_ast), do: do_step(pattern, fun_ast, :then, __CALLER__)
  defmacro step(pattern, fun_ast), do: do_step(pattern, fun_ast, :step, __CALLER__)

  defmacro pending do
    quote do: throw(:cucumberex_pending)
  end

  defmacro world_module(mod) do
    quote do
      @__cucumberex_world_modules__ unquote(mod)
    end
  end

  defmacro parameter_type(name, regexp, transformer) do
    quote do
      @__cucumberex_param_types__ {unquote(name), unquote(regexp), unquote(transformer)}
    end
  end

  defp do_step(pattern_ast, fun_ast, keyword, caller) do
    location = "#{Path.relative_to_cwd(caller.file)}:#{caller.line}"
    counter = :erlang.unique_integer([:positive, :monotonic])
    fun_name = :"__cucumberex_step_#{counter}__"

    # Serialize regex patterns: Regex structs contain NIF references (can't Macro.escape).
    # Convert ~r/.../ AST to {:regex, source, flags} tuple (all strings — escapable).
    serialized_pattern = serialize_pattern(pattern_ast)

    quote do
      def unquote(fun_name)(__world__, __args__) do
        apply(unquote(fun_ast), [__world__ | __args__])
      end

      @__cucumberex_steps__ {
        unquote(Macro.escape(serialized_pattern)),
        unquote(keyword),
        unquote(location),
        unquote(fun_name)
      }
    end
  end

  # ~r/.../ sigil AST → {:regex, source, flags} — all strings, Macro.escape-safe
  defp serialize_pattern({:sigil_r, _, [{:<<>>, _, parts}, flags]}) do
    source = Enum.join(parts)
    flag_str = to_string(flags)
    {:regex, source, flag_str}
  end

  defp serialize_pattern({:sigil_R, _, [{:<<>>, _, parts}, flags]}) do
    source = Enum.join(parts)
    flag_str = to_string(flags)
    {:regex, source, flag_str}
  end

  defp serialize_pattern(pattern), do: pattern

  @doc "Load a step module into the registry."
  def load_module(module, registry \\ Cucumberex.StepDefinition.Registry) do
    Code.ensure_loaded!(module)

    if function_exported?(module, :__cucumberex_steps__, 0) do
      module.__cucumberex_steps__()
      |> Enum.each(fn {raw_pattern, keyword, location, fun_name} ->
        pattern = deserialize_pattern(raw_pattern)

        step_def = %Cucumberex.StepDefinition{
          id: UUID.uuid4(),
          pattern: pattern,
          fun: {module, fun_name},
          location: location,
          keyword: keyword
        }

        Cucumberex.StepDefinition.Registry.register(registry, step_def)
      end)
    end
  end

  defp deserialize_pattern({:regex, source, flags}), do: Regex.compile!(source, flags)
  defp deserialize_pattern(pattern), do: pattern

  @doc "Execute step: fun is {module, fun_name} or an anonymous fn."
  def execute_step({module, fun_name}, world, args) do
    result = apply(module, fun_name, [world, args])
    normalize_result(result, world)
  rescue
    e -> {:error, e, world}
  catch
    :cucumberex_pending -> {:pending, world}
  end

  def execute_step(fun, world, args) when is_function(fun) do
    result = apply(fun, [world | args])
    normalize_result(result, world)
  rescue
    e -> {:error, e, world}
  catch
    :cucumberex_pending -> {:pending, world}
  end

  defp normalize_result({:ok, new_world}, _world) when is_map(new_world), do: {:ok, new_world}
  defp normalize_result(new_world, _world) when is_map(new_world), do: {:ok, new_world}
  defp normalize_result(_, world), do: {:ok, world}
end
