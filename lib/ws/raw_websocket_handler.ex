defmodule Ws.RawWebsocketHandler do
  @behaviour Phoenix.Socket.Transport

  # <https://hexdocs.pm/phoenix/Phoenix.Socket.Transport.html#module-example>

  require Logger

  def child_spec(_opts) do
    # We won't spawn any process, so let's ignore the child spec
    :ignore
  end

  def connect(%{params: %{"token" => token}} = info) do
    Logger.debug("connect")

    case Phoenix.Token.verify(WsWeb.Endpoint, "user socket", token, max_age: 86_400) do
      {:ok, user_id} ->
        {:ok, Map.put(info, :user_id, user_id)}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_info), do: :error

  def init(state) do
    Logger.debug("init")
    :ok = WsWeb.Endpoint.subscribe("files")
    {:ok, state}
  end

  def handle_in({"ping", [opcode: :text]}, state) do
    Logger.info("Received ping from the browser")
    {:reply, :ok, {:text, "ping"}, state}
  end

  def handle_in({"request-from-server", [opcode: :text]}, state) do
    data = File.read!("ws.jpg")
    {:reply, :ok, {:binary, data}, state}
  end

  def handle_in({msg, [opcode: :text]}, state) do
    Logger.info("Received text via WS...#{inspect(msg)}")
    {:ok, state}
  end

  def handle_in({img, [opcode: :binary]}, state) do
    Logger.info("WS Received binary")
    File.write("ws.jpg", img)
    {:reply, :ok, {:text, "Image received via WS saved on disk"}, state}
  end

  # for LiveView
  def handle_info(%{topic: "files", event: "upload", payload: %{file: file}}, state) do
    data = File.read!(file)
    {:push, {:binary, data}, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
