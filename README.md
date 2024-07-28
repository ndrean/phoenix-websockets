# WebSockets with Elixir Phoenix LiveView

## Overview of WebSocket Options

We want to pass data via a WebSocket connection between the `Elixir/Phoenix` server and the browser.

We consider the following options:

1. LiveSocket
   1. Uses LiveView under the hood for real-time updates
   2. Client-side implementation uses "hooks" with pushEvent and handleEvent from Phoenix.js.
2. Elixir Channel
   1. Built on top of Phoenix.Socket, providing higher-level abstraction.
   2. Features reconnection and fallback to long-polling.
   3. Client-side: Instantiate new Socket("/socket"), use channel.push and channel.on.
   4. Allows fine-grained authorization per channel.
3. Custom WebSocket
   1. Utilizes the WebSocket API directly.
   2. Implement the Phoenix.Socket.Transport behaviour server-side in a module declared in "endpoint.ex".
4. Elixir WebSocket client
   1. Use libraries like Fresh to connect to WebSocket endpoints directly from Elixir applications.
   2. Suitable for client-side connections within Elixir, distinct from Phoenix's server-side WebSocket handling.

## Choosing the Right Approach

We are mostly interested by sending images, possibly large, fron the server to the browser, or from the browser to the server.

## LiveSocket implementation with base64 encoding

### Sending Images from Server to Browser

We can send an image as _base64_ encoded string via the LiveSocket. We load an image from the file-system in the server and display it. In a `LiveView`, we can do:

```elixir
image_base64 =
  File.read!(file)
  |> Base.encode64(image_binary)
```

then update an assign:

`assign(socket, :image_base64, image_base64)`,

and then it will render when the assigns are udpated:

```elixir
def render(assigns) do
  ~H"""
  [...]
  <img src={"data:image/jpeg;base64,#{@image_base64}"} />
  """
end
```

This is done along the `LiveSocket`. It sends the data as base 64 encoded text to the browser.

### Sending Images from Browser to Server

If we want to send from the browser, say from a hook, we transform again the data into a base64 encoded string and send it via the LiveSocket:

```js
const sendBase64ViaLiveSocket = (blob) => {
  const reader = new FileReader();
  reader.readAsDataURL(blob);
  reader.onload = () => {
    this.pushEvent("send_as_base64", {
      data_as_b64: reader.result,
    });
  };
};
```

However, we don't want to use base64 encoded strings as this increases the size of the data by 30%. This is inconvienient if the file is big or have many images.

### Channel implementation

Channels are processes built on top of the WebSocket.

#### Setting Up Channels

We instantiate our "userSocket"

<details>
<summary>UserSocket.js
</summary>

```js
import { Socket } from "phoenix";

const userSocket = new Socket("/userSocket", {
  params: { userToken: window.userToken },
});
userSocket.connect();

export default userSocket;
```

</details>
<br/>

<details>
<summary>A generic implementation of a Channel client-side
</summary>

```js
export default function useChannel(socket, topic) {
  return new Promise((resolve, reject) => {
    if (!socket) {
      reject(new Error("Socket not found"));
      return;
    }

    const channel = socket.channel(topic, { token: window.userToken });
    channel
      .join()
      .receive("ok", () => {
        console.log(`Joined successfully Channel : ${topic}`);
        resolve(channel);
      })
      .receive("error", (resp) => {
        console.log(`Unable to join ${topic}`, resp.reason);
        reject(new Error(resp.reason));
      });
  });
}
```

</details>
<br/>

We instantiate the "userSocket" and a Channel with a given "topic"

```js
import userSocket from "./userSocket";
import useChannel from "./useChannel";
const channel = useChannel(userSocket, "topic");
```

This "userSocket" is declared in the Elixir "endpoint.ex" module, and the server-side Elixir module to handle the Channel is declared in the "user_socket.ex" module.

#### Streaming Large Files from Server to Browser

We use the possibility of the `handle_in` callback to respond with binary data. The browser sends a demand for the server to upload a file from the ifie system and the response is:

```elixir
def handle_in("request-image", _, socket) do
  File.stream!("channel.jpg", 1024 * 10)
  |> Stream.with_index()
  |> Enum.each(fn {chunk, index} ->
    IO.puts("CH: sending chunk #{index}")
    push(socket, "new chunk", {:binary, <<index::32, chunk::binary>>})
  end)

  push(socket, "image complete", %{})

  {:noreply, socket}
end
```

The client-side code is:

```js
imageChannel.on("new chunk", (payload) => {
  if (payload instanceof ArrayBuffer) {
    let view = new DataView(payload);
    let index = view.getInt32(0);
    let chunk = payload.slice(4);
    console.log("Channel: received chunk ", index);
    imageChunks[index] = chunk;
    totalChunks++;
  }
});

imageChannel.on("image complete", () => {
  imageChunks = imageChunks.filter((chunk) => chunk !== undefined);
  let blob = new Blob(imageChunks, { type: "image/jpeg" });
  imageURL = URL.createObjectURL(blob);
  document.getElementById("from-server-via-channel").src = imageURL;
});
```

<details>
<summary>
If we don't send chunks but directly the whole file, then we would simply have:
</summary>

```elixir
def handle_in("request-image", _, socket) do
  data = File.read!("channel.jpg")
  {:reply, {:ok, {:binary, data}}, state}
end
```

and the client code could be:

```js
function displayReceivedMsg(payload, topic, picId) {
  const { response, status } = payload;
  if (response instanceof ArrayBuffer) {
    console.log("Received a pic via Channel", status);
    let blob = new Blob([response], { type: "image/jpeg" });
    let imageUrl = URL.createObjectURL(blob);
    document.getElementById(picId).src = imageUrl;
  } else {
    console.log("Channel received a message :", topic);
  }
}
```

</details>

#### Streaming Large Files from Browser to Server

You have the Phoenix LiveView Uplaods.

An example if you have an endpoint that serves large files and you want to download and push through a Channel.

<details>
<summary> An example of client code

```js
const sendLargeFileViaChannel = async (channel) => {
  let url =
    "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4";
  const response = await fetch(url);
  const reader = response.body.getReader();
  const contentLength = +response.headers.get("Content-Length");
  console.log(contentLength);

  let receivedLength = 0;
  let chunks = [];
  const chunkSize = 1024 * 1024 * 5; // 5MB chunks

  while (true) {
    const { done, value } = await reader.read();

    if (done) {
      console.log("Transfer completed");
      break;
    }

    receivedLength += value.length;
    chunks.push(value);

    if (chunks.length * chunkSize >= chunkSize) {
      const blob = new Blob(chunks).slice(0, chunkSize);
      const arrayBuffer = await blob.arrayBuffer();
      channel.push("chunk", arrayBuffer);
      chunks = [new Blob(chunks).slice(chunkSize)];
    }

    console.log(`Received ${receivedLength} of ${contentLength} bytes`);
  }

  // Send any remaining data
  if (chunks.length > 0) {
    channel.push("chunk", new Blob(chunks));
  }
};
```

and the server code is:

```elixir
def handle_in("chunk", {:binary, data}, socket) when is_binary(data) do
  # IO.puts("CH: received chunk")
  File.write("large.mp4", data, [:append])
  {:noreply, socket}
end

def handle_in("chunk", %{}, socket) do
  {:noreply, socket}
end
```

</details>
<br/>

### Raw WebSocket Implementation

We use the WebSocket API to the `Elixir` server. We send data to the server.

### Client-Side Setup

<details>
<summary>Client implementation of raw WebSocket
</summary>

```js
let protocole = window.location.protocol.includes("https") ? "wss" : "ws";
let url = "https://picsum.photos/300/300.jpg",
let ws = new WebSocket(
  `${protocole}://${window.location.host}/rawsocket?token=${window.userToken}`
);

ws.onopen = async () => {
  const response = await fetch(url);
  const blob = await response.blob();
  const arrayBuffer = await blob.arrayBuffer();
  ws.send(arrayBuffer);
};
```

</details>
<br/>

### Server-Side Setup

Server-side, we have:

```elixir
# endpoint.ex

 socket "/rawsocket", WsHandler,
    websocket: [
      path: "",
      check_origin: Application.compile_env(:ws, :websocket_origins)
    ]
```

The server module "WsHandler" receives binary data:

```elixir
defmodule WsHandler do
  @behaviour Phoenix.Socket.Transport

  # <https://hexdocs.pm/phoenix/Phoenix.Socket.Transport.html#module-example>

  def child_spec(\_opts); do: :ignore

  def connect(%{params: %{"token" => token}} = info) do
    case Phoenix.Token.verify(WsWeb.Endpoint, "user socket", token, max_age: 86400) do
      {:ok, user_id} ->
        {:ok, Map.put(info, :user_id, user_id)}

      {:error, _reason} ->
        :error
    end
  end

  def connect(\_info), do: :error

  def init(state); do: {:ok, state}

  def handle_in({img, [opcode: :binary]}, state) do
    # for example, lets save the data inot a file
    File.write("data.jpg", img)
    {:ok, state}
  end
end
```

### Elixir WebSocket Client

#### Connecting to External WebSocket Stream

We want connect to a realtime WebSocket stream ([coincap.io](https://docs.coincap.io/#37dcec0b-1f7b-4d98-b152-0217a6798058)) and use a realtime charting library to display the data.

In our LiveView `mount/3`, we supervise the module that instantiates the connection:

```elixir
symbol = "bitcoin"
if connected?(socket) do
  DynamicSupervisor.start_child(DynSup, {
    Ws.ClientWebsocketHandler,
    uri: "wss://ws.coincap.io/prices?assets=" <> symbol, state: %{symbol: symbol}
  })
  MyApp.Endpoint.subscribe("price")
```

The connection module uses the WebSocket client [Fresh](https://hexdocs.pm/fresh/readme.html).
Once we receive data, we "pubsub" it. The LiveView subscribed to this topic.

```elixir
defmodule MyApp.ClientWebsocketHandler do
  use Fresh

  def handle_connect(101, _headers, socket) do
    {:reply, [], socket}
  end

  def handle_in({:text, payload}, state) do
    %{symbol: symbol} = state

    value =
      Jason.decode!(payload)
      |> Map.get(symbol)

    :ok = MyAppWeb.Endpoint.broadcast("price", "new", %{value: value})
    {:ok, state}
  end
end
```

To send data to the client module, we push it via the LiveSocket:

```elixir
def handle_info(%{topic: "price", event: "new", payload: %{value: value}}, socket) do
  {:noreply, push_event(socket, "new", %{value: value})}
end
```

#### Real-time Data Visualization

To render a chart, we used "lightweight-charts" from [TradingView](https://github.com/tradingview/lightweight-charts).

We copied the [library code](https://unpkg.com/lightweight-charts/dist/lightweight-charts.standalone.production.js) into the **"vendor" folder**.

The library exposes the object `LightWeightCharts` directly on the `window`.

We use it in a "hook" and use `handleEvent` to receive the data and inject it into the chart.

<details>
<summary>Client code</summary>

```js
import "../vendor/lightweightCharts";

export const chartHook = {
  mounted() {
    const chart = window.LightweightCharts.createChart(this.el, {
      width: window.innerWidth * 0.6,
      height: window.innerHeight * 0.4,
      rightPriceScale: {
        visible: true,
      },
      leftPriceScale: {
        visible: true,
      },
    });
    const btc = chart.addLineSeries({ priceScaleId: "right" });

    chart.timeScale().fitContent();

    this.handleEvent("new", ({ value }) => {
      const newPriceEvt = {
        time: new Date().getTime() / 1000,
        value: Number(value),
      };
      btc.update(newPriceEvt);
    });

    window.addEventListener("resize", () => {
      chart.resize(window.innerWidth * 0.6, window.innerHeight * 0.4);
    });
  },
};
```

</details>
