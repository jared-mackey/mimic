defmodule Mimic.ModuleLoader do
  @moduledoc false

  use GenServer

  defp name(module) do
    "#{module}.Loader" |> String.to_atom()
  end

  def store_filename_and_cover_data(module, filename, cover_data) do
    GenServer.cast(name(module), {:store_filename_and_cover_data, module, filename, cover_data})
  end

  def rename_module(module) do
    GenServer.call(name(module), {:rename_module, module}, 60_000)
  end

  def reset(module) do
    GenServer.call(name(module), {:reset, module}, :infinity)
  end

  def store_beam_code(module, beam_code, compiler_options) do
    GenServer.call(name(module), {:store_beam_code, module, beam_code, compiler_options})
  end

  def start_link(module) do
    GenServer.start_link(__MODULE__, [], name: name(module))
  end

  def init([]) do
    {:ok, %{cover_data: %{}}}
  end

  def handle_cast({:store_filename_and_cover_data, module, filename, cover_data}, state) do
    cover_data = Map.put(state.cover_data, module, {filename, cover_data})
    {:noreply, %{state | cover_data: cover_data}}
  end

  def handle_call({:store_beam_code, module, beam_code, compiler_options}, _from, state) do
    Mimic.Server.store_beam_code(module, beam_code, compiler_options)

    {:reply, :ok, state}
  end

  def handle_call({:rename_module, module}, _from, state) do
    case Mimic.Server.fetch_beam_code(module) do
      [{^module, beam_code, compiler_options}] ->
        Mimic.Module.rename_module(module, beam_code, compiler_options)
        Mimic.Server.delete_beam_code(module)

      _ ->
        :ok
    end

    {:reply, :ok, state}
  end

  def handle_call({:reset, module}, _from, state) do
    case state.cover_data[module] do
      {filename, cover_data} ->
        Mimic.Cover.replace_cover_data!(module, filename, cover_data)

      _ ->
        Mimic.Module.clear!(module)

        module
        |> Mimic.Module.original()
        |> Mimic.Module.clear!()
    end

    cover_data = Map.delete(state.cover_data, module)

    {:reply, :ok, %{state | cover_data: cover_data}}
  end
end
