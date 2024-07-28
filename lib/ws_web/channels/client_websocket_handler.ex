defmodule Ws.ClientWebsocketHandler do
  @moduledoc """
  Elixir WebSocket client handler for the `Fresh` client
  """

  use Fresh

  def handle_connect(101, _headers, socket) do
    {:reply, [], socket}
  end

  def handle_in({:text, payload}, state) do
    %{symbol: symbol} = state

    value =
      Jason.decode!(payload)
      |> Map.get(symbol)

    :ok = WsWeb.Endpoint.broadcast("price", "new", %{value: value})
    {:ok, state}
  end
end
