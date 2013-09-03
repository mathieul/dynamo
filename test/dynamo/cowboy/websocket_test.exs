defmodule Dynamo.Cowboy.WebsocketTest do
  use ExUnit.Case, async: true

  defmodule WebsocketHandler1 do
    @behaviour :cowboy_websocket_handler
    def websocket_init(_transport_name, req, _opts), do: { :ok, req, :undefined_state }
    def websocket_handle(_data, req, state), do: { :ok, req, state}
    def websocket_info(_data, req, state), do: { :ok, req, state }
    def websocket_terminate(_reason, _req, _state), do: :ok
  end

  defmodule WebsocketHandler2 do
    use Dynamo.Cowboy.Websocket

    on_init do
      IO.puts "on_init: conn = #{inspect conn}"
      if conn.params[:nick] do
        self <- { :send_text, "room=#{conn.params[:room]}-nick=#{conn.params[:nick]}" }
      end
      state
    end

    def websocket_info({ :send_text, message }, req, state) do
      # IO.puts "SERVER: info { :send_text, #{inspect message} }"
      { :reply, { :text, message }, req, state }
    end
    def websocket_info(_data, req, state), do: { :ok, req, state }
    def websocket_handle( { :text, message }, req, state) do
      # IO.puts "SERVER: handle { :text, #{inspect message} }"
      { :reply, {:text, "server: #{message}" }, req, state }
    end
    def websocket_handle(_data, req, state), do: { :ok, req, state}
    def websocket_terminate(_reason, _req, _state), do: :ok
  end

  defmodule WebsocketHandler2Old do
    @behaviour :cowboy_websocket_handler
    def websocket_init(_transport_name, req, conn) do
      if conn.params[:nick] do
        self <- { :send_text, "room=#{conn.params[:room]}-nick=#{conn.params[:nick]}" }
      end
      { :ok, req, :undefined_state }
    end
    def websocket_info({ :send_text, message }, req, state) do
      # IO.puts "SERVER: info { :send_text, #{inspect message} }"
      { :reply, { :text, message }, req, state }
    end
    def websocket_info(_data, req, state), do: { :ok, req, state }
    def websocket_handle( { :text, message }, req, state) do
      # IO.puts "SERVER: handle { :text, #{inspect message} }"
      { :reply, {:text, "server: #{message}" }, req, state }
    end
    def websocket_handle(_data, req, state), do: { :ok, req, state}
    def websocket_terminate(_reason, _req, _state), do: :ok
  end

  defmodule ApplicationRouter do
    use Dynamo.Router

    prepare do: conn.fetch(:params)

    websocket "/ws/:room", using: WebsocketHandler2
    websocket "/ws", using: WebsocketHandler1
  end

  defmodule WebsocketClient do
    @behaviour :websocket_client_handler
    def start_link(url, pid), do: :websocket_client.start_link(url, __MODULE__, [pid])
    def init([pid], _conn_state) do
      pid <- { :ws_initialized, :ok }
      { :ok, pid }
    end
    def websocket_handle({ :text, message }, _conn_state, pid) do
      # IO.puts "CLIENT: handle { :text, #{inspect message} }"
      pid <- { :ws_text_received, message }
      { :ok, pid }
    end
    def websocket_handle(_data, _conn_state, state), do: { :ok, state }
    def websocket_info({ :send_text, message }, _conn_state, pid) do
      # IO.puts "CLIENT: info { :send_text, #{inspect message} }"
      { :reply, { :text, message }, pid }
    end
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

  # test "websocket clients can connect" do
  #   WebsocketClient.start_link('ws://127.0.0.1:8011/ws', self)
  #   wait_for(:ws_initialized, "client was not initialized as expected")
  # end

  test "on init the websocket server can access params" do
    WebsocketClient.start_link('ws://127.0.0.1:8011/ws/42?nick=zorn', self)
    wait_for(:ws_initialized)
    message = wait_for(:ws_text_received, "client did not receive params message")
    assert message == "room=42-nick=zorn"
  end

  # test "websocket clients can send and receive text messages" do
  #   { :ok, client } = WebsocketClient.start_link('ws://127.0.0.1:8011/ws/123', self)
  #   wait_for(:ws_initialized)
  #   client <- { :send_text, "hello there" }
  #   message = wait_for(:ws_text_received, "client did not receive message sent")
  #   assert message == "server: hello there"
  # end

  defp wait_for(expected, error // "message was not received as expected") do
    receive do
      { message, data } ->
        if message == expected do
          assert true
          data
        else
          assert false, error
        end
    after
      500 -> assert false, error
    end
  end
end
