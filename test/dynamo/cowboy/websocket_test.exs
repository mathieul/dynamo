defmodule Dynamo.Cowboy.WebsocketTest do
  use ExUnit.Case, async: true

  defmodule WebsocketHandler do
    @behaviour :cowboy_websocket_handler
    def websocket_init(_transport_name, req, _opts), do: { :ok, req, :undefined_state }
    def websocket_handle(_data, req, state), do: { :ok, req, state}
    def websocket_info(_data, req, state), do: { :ok, req, state }
    def websocket_terminate(_reason, _req, _state), do: :ok
  end

  defmodule ApplicationRouter do
    use Dynamo.Router
    websocket "/ws", using: WebsocketHandler
  end

  defmodule WebsocketClient do
    @behaviour :websocket_client_handler
    def start_link(url, pid), do: :websocket_client.start_link(url, __MODULE__, [pid])
    def init([pid], _conn_state) do
      pid <- :ws_initialized
      { :ok, :undefined_state }
    end
    def websocket_handle(_data, _conn_state, state), do: { :ok, state }
    def websocket_info(_data, _conn_state, state), do: { :ok, state }
    def websocket_terminate(_reason, _conn_state, _state), do: :ok
  end

  setup_all do
    Dynamo.Cowboy.run ApplicationRouter, port: 8011, verbose: false
    :ok
  end

  teardown_all do
    Dynamo.Cowboy.shutdown ApplicationRouter
    :ok
  end

  test "initialization" do
    WebsocketClient.start_link('ws://127.0.0.1:8011/ws', self)
    wait_for(:ws_initialized, "websocket client was not initialized as expected")
  end

  defp wait_for(expected, error) do
    receive do
      message ->
        if message == expected, do: assert(true), else: assert(false, error)
    after
      500 -> assert false, error
    end
  end
end
