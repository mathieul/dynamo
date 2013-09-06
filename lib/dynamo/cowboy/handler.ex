defmodule Dynamo.Cowboy.Handler do
  @moduledoc false

  @behaviour :cowboy_http_handler
  @behaviour :cowboy_websocket_handler

  require :cowboy_req, as: R

  # HTTP

  defp scheme(:tcp), do: :http
  defp scheme(:ssl), do: :https

  def init({ transport, :http }, req, main) when transport in [:tcp, :ssl] do
    conn = main.service(Dynamo.Cowboy.Connection.new(main, req, scheme(transport)))

    { websocket_init, _req } = R.meta(:websocket_init, conn.cowboy_request)
    cond do
      websocket_init != :undefined ->
        req = R.set_meta(:websocket_init, nil, conn.cowboy_request)
        { :upgrade, :protocol, :cowboy_websocket, req, websocket_init }
      is_record(conn, Dynamo.Cowboy.Connection) ->
        { :ok, conn.cowboy_request, nil }
      true ->
        raise "Expected service to return a Dynamo.Cowboy.Connection, got #{inspect conn}"
    end
  end

  def handle(req, nil) do
    { :ok, req, nil }
  end

  def terminate(_reason, _req, nil) do
    :ok
  end

  # Websockets

  def websocket_init(any, req, init) do
    { mod, req } = R.meta(:websocket_handler, req)
    mod.websocket_init(any, req, init)
  end

  def websocket_handle(msg, req, state) do
    { mod, req } = R.meta(:websocket_handler, req)
    mod.websocket_handle(msg, req, state)
  end

  def websocket_info(msg, req, state) do
    { mod, req } = R.meta(:websocket_handler, req)
    mod.websocket_info(msg, req, state)
  end

  def websocket_terminate(reason, req, state) do
    { mod, req } = R.meta(:websocket_handler, req)
    mod.websocket_terminate(reason, req, state)
  end
end
