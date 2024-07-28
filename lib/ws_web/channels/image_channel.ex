defmodule WsWeb.ImageChannel do
  use Phoenix.Channel

  @impl true
  def join("image", %{"token" => user_token}, socket) do
    case Phoenix.Token.verify(WsWeb.Endpoint, "user socket", user_token, max_age: 86_400) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}

      {:error, _reason} ->
        :error
    end
  end

  @impl true
  def handle_in("pic-to-server", {:binary, data}, socket) do
    IO.puts("CH: received binary")
    File.write("channel.jpg", data)
    push(socket, "image-saved-to-disk", %{text: "Image received via Channel saved on disk"})
    {:noreply, socket}
  end

  def handle_in("request-image", _, socket) do
    # data = File.read!("channel.jpg")
    File.stream!("channel.jpg", 1024 * 10)
    |> Stream.with_index()
    |> Enum.each(fn {chunk, index} ->
      IO.puts("CH: sending chunk #{index}")
      push(socket, "new chunk", {:binary, <<index::32, chunk::binary>>})
    end)

    push(socket, "image complete", %{})

    {:noreply, socket}
  end

  def handle_in("chunk", {:binary, data}, socket) when is_binary(data) do
    # IO.puts("CH: received chunk")
    File.write("large.mp4", data, [:append])
    {:noreply, socket}
  end

  def handle_in("chunk", %{}, socket) do
    {:noreply, socket}
  end
end
