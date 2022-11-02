defmodule WebSock.CowboyAdapter do
  @moduledoc false

  @behaviour :cowboy_websocket

  # Cowboy never actually calls this implementation due to the way that Plug.Cowboy signals
  # upgrades; it's just here to quell compiler warnings
  @impl true
  def init(req, state), do: {:cowboy_websocket, req, state}

  @impl true
  def websocket_init({handler, process_flags, state}) do
    for {key, value} <- process_flags do
      :erlang.process_flag(key, value)
    end

    handler.init(state)
    |> handle_reply(handler)
  end

  @impl true
  def websocket_handle({opcode, payload}, {handler, state}) when opcode in [:text, :binary] do
    handler.handle_in({payload, opcode: opcode}, state)
    |> handle_reply(handler)
  end

  def websocket_handle({opcode, payload}, {handler, state}) when opcode in [:ping, :pong] do
    if function_exported?(handler, :handle_control, 2) do
      handler.handle_control({payload, opcode: opcode}, state)
    else
      {:ok, state}
    end
    |> handle_reply(handler)
  end

  def websocket_handle(opcode, handler_state) when opcode in [:ping, :pong] do
    websocket_handle({opcode, nil}, handler_state)
  end

  def websocket_handle(_other, handler_state) do
    {:ok, handler_state}
  end

  @impl true
  def websocket_info(message, {handler, state}) do
    handler.handle_info(message, state)
    |> handle_reply(handler)
  end

  @impl true
  def terminate({:remote, code, _}, _req, {handler, state})
      when code in 1000..1003 or code in 1005..1011 or code == 1015 do
    handler.terminate(:remote, state)
  end

  def terminate({:remote, :closed}, _req, {handler, state}), do: handler.terminate(:closed, state)
  def terminate(:remote, _req, {handler, state}), do: handler.terminate(:remote, state)
  def terminate(:stop, _req, {handler, state}), do: handler.terminate(:normal, state)
  def terminate(reason, _req, {handler, state}), do: handler.terminate(reason, state)

  defp handle_reply({:ok, state}, handler), do: {:ok, {handler, state}}
  defp handle_reply({:push, data, state}, handler), do: {:reply, data, {handler, state}}
  defp handle_reply({:reply, _status, data, state}, handler), do: {:reply, data, {handler, state}}
  defp handle_reply({:stop, _reason, state}, handler), do: {:stop, {handler, state}}
end
