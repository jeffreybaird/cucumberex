defmodule Cucumberex.Hooks.DSL do
  @moduledoc """
  Hook definition DSL. Use in support files:

      use Cucumberex.Hooks.DSL

      before_ fn world -> Map.put(world, :db, start_db()) end

      before_ "@smoke", fn world -> Map.put(world, :smoke, true) end

      after_ fn world ->
        cleanup(world.db)
        world
      end

      around_ fn world, run ->
        result = run.(world)
        cleanup(world)
        result
      end

      before_all_ fn -> :ok end

      after_all_ fn -> :ok end
  """

  defmacro __using__(_opts) do
    quote do
      import Cucumberex.Hooks.DSL
      Module.register_attribute(__MODULE__, :__cucumberex_hooks__, accumulate: true)
      @before_compile Cucumberex.Hooks.DSL
    end
  end

  defmacro __before_compile__(env) do
    hooks = env.module |> Module.get_attribute(:__cucumberex_hooks__, []) |> Enum.reverse()

    quote do
      def __cucumberex_hooks__, do: unquote(Macro.escape(hooks))
    end
  end

  defmacro before_(fun), do: do_hook(:before, nil, fun, __CALLER__)
  defmacro before_(tags, fun), do: do_hook(:before, tags, fun, __CALLER__)
  defmacro after_(fun), do: do_hook(:after, nil, fun, __CALLER__)
  defmacro after_(tags, fun), do: do_hook(:after, tags, fun, __CALLER__)
  defmacro around_(fun), do: do_hook(:around, nil, fun, __CALLER__)
  defmacro around_(tags, fun), do: do_hook(:around, tags, fun, __CALLER__)
  defmacro before_step_(fun), do: do_hook(:before_step, nil, fun, __CALLER__)
  defmacro after_step_(fun), do: do_hook(:after_step, nil, fun, __CALLER__)
  defmacro before_all_(fun), do: do_hook(:before_all, nil, fun, __CALLER__)
  defmacro after_all_(fun), do: do_hook(:after_all, nil, fun, __CALLER__)
  defmacro install_plugin_(fun), do: do_hook(:install_plugin, nil, fun, __CALLER__)

  defp do_hook(phase, tags, fun_ast, caller) do
    location = "#{Path.relative_to_cwd(caller.file)}:#{caller.line}"
    counter = :erlang.unique_integer([:positive, :monotonic])
    fun_name = :"__cucumberex_hook_#{counter}__"

    fun_def =
      if phase in [:before_all, :after_all, :install_plugin] do
        quote do
          def unquote(fun_name)() do
            apply(unquote(fun_ast), [])
          end
        end
      else
        quote do
          def unquote(fun_name)(__world__) do
            apply(unquote(fun_ast), [__world__])
          end
        end
      end

    quote do
      unquote(fun_def)

      @__cucumberex_hooks__ {
        unquote(phase),
        unquote(tags),
        unquote(location),
        unquote(fun_name)
      }
    end
  end

  def load_module(module, registry \\ Cucumberex.Hooks.Registry) do
    Code.ensure_loaded!(module)

    if function_exported?(module, :__cucumberex_hooks__, 0) do
      module.__cucumberex_hooks__()
      |> Enum.each(fn {phase, tags, location, fun_name} ->
        fun = build_hook_fun(module, fun_name, phase)
        hook = Cucumberex.Hook.new(phase, fun, tags: tags, location: location)
        Cucumberex.Hooks.Registry.register(registry, hook)
      end)
    end
  end

  defp build_hook_fun(module, fun_name, phase)
       when phase in [:before_all, :after_all, :install_plugin] do
    fn -> apply(module, fun_name, []) end
  end

  defp build_hook_fun(module, fun_name, _phase) do
    fn world -> apply(module, fun_name, [world]) end
  end
end
