defmodule WsWeb.UserSocket do
  use Phoenix.Socket

  channel "image", WsWeb.ImageChannel

  @impl true
  def connect(%{"userToken" => user_token}, socket) do
    case Phoenix.Token.verify(WsWeb.Endpoint, "user socket", user_token, max_age: 86_400) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}

      {:error, _reason} ->
        :error
    end
  end

  @impl true
  def id(_socket), do: nil
end
