defmodule Dynamo.Cowboy.Websocket do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      @behaviour :cowboy_websocket_handler
      defrecordp :context, __MODULE__, [:params]
      import unquote(__MODULE__)
    end
  end

  defmacro on_init(do: block) do
    quote do
      def websocket_init(_transport_name, req, state) do
        [connection: conn, state: state] = state
        block_returns = unquote(do: block)
        IO.puts "macro: block_returns = #{inspect block_returns}"
        { :ok, req, [ connection: conn, state: block_returns ] }
      end
    end
  end
end
