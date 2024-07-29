defmodule WsWeb.MainLive do
  use WsWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="px-4 py-8 sm:px-6 sm:py-12 md:px-8 md:py-16 lg:px-12 lg:py-20 xl:px-16 xl:py-24"
      id="main"
    >
      <div class="mx-auto max-w-xl lg:max-w-4xl xl:max-w-5xl">
        <div class="flex flex-col lg:flex-row justify-center items-center gap-8 lg:gap-12">
          <h1 id="direct-browser" phx-hook="pushHook">
            The "standard" way to fetch a random image on the internet and render it directly into the browser
          </h1>
          <figure>
            <img
              id="direct-browser-fetch"
              class="max-w-[512px] min-w-[512px] h-auto"
              alt="Directly fetched image"
              phx-update="ignore"
            />
            <figcaption>
              You need to use <code>phx-update="ignore"</code>
            </figcaption>
          </figure>
          <br />
          <h1 id="round-trip">
            The same image is sent to the server via the <code>LiveSocket</code>
            as <strong>base 64</strong>
            encoded string.
            We update an assign to render it, so the LiveSocket sends it back to the browser.
          </h1>
          <figure>
            <img
              id="received-as-b46-via-livesocket"
              src={@image_base64}
              class="max-w-[512px] min-w-[512px] h-auto"
              alt="Round trip as base64 via LiveSocket"
            />
            <figcaption>
              The "round trip". The initial size is <%= @blob_size %>, and the encoded size is <%= @encoded_len %>
            </figcaption>
          </figure>
          <br />

          <.button id="produce-base64" type="button" phx-click="produce-base64">
            Generate base64
          </.button>
          <figure>
            <img
              id="received-as-text-via-livesocket"
              src={"data:image/jpeg;base64,#{@b64_data}"}
              class="max-w-[512px] min-w-[512px] h-auto"
            />
            <figcaption>
              Fetched on the server and sent back to the browser as base64 encoded string via the LiveSocket rendering
            </figcaption>
          </figure>
          <br />
          <h1 id="raw" phx-hook="rawWebSocketHook">
            <%!-- <h1> --%> This image is randomly fetched on the internet and send from  via the
            <strong>raw WebSocket</strong>
            to the server, where we save it on disk
          </h1>
          <.button id="send-via-ws">Send via WebSocket</.button>
          <figure>
            <img id="display-img-sent-to-server-via-ws" class="max w-[512px] min-w-[512px] h-auto" />
            <figcaption>Image sent to the server via a raw WebSocket</figcaption>
          </figure>
          <br />
          <h1 id="channel" phx-hook="channelHook">
            This image is randomly fetched on the internet and send it via a <strong>Channel</strong>
            to the server, where we save it on disk
          </h1>
          <.button id="send-via-channel">Send via Channel</.button>
          <figure>
            <img id="display-img-sent-to-server-via-ch" class="max-w-[512px] min-w-[512px] h-auto" />
            <figcaption>Image sent to the server via a Channel</figcaption>
          </figure>
          <br />

          <br />
          <hr />
          <.button id="request-data-from-channel" type="button">
            Retrieve picture from disk via a Channel in chunks
          </.button>
          <br />
          <img id="from-server-via-channel" class="w-full max-w-[512px] min-w-[512px] h-auto" />
          <br />
          <hr />
          <.button id="request-data-from-ws" disabled type="button">
            Retrieve picture from disk via a WS
          </.button>
          <br />
          <img id="from-server-via-ws" class="w-full max-w-[512px] min-w-[512px] h-auto mt-8 lg:mt-0" />
          <br />
          <div>
            <h1>
              Realtime charting receiving data from the Elixir WebSocket client <code>Fresh</code>. We used
              <a href="https://www.tradingview.com/symbols/NASDAQ-AAPL/" target="_blank">
                TradingView's "lightweight-charts"
              </a>
              for the chart.
            </h1>
            <br />
            <div id="chart" phx-hook="StockChart" phx-update="ignore"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp encrypt_csrf_into_ets(session_csrf_token) do
    encrypted_csrf = Phoenix.Token.sign(WsWeb.Endpoint, "csrf token", session_csrf_token)
    :ets.insert(:my_token, {"user_id", encrypted_csrf})
  end
  
  @impl true
  def mount(_params, _session, socket) do
    user_token = Phoenix.Token.sign(WsWeb.Endpoint, "user socket", "user_id")
    
    if connected?(socket) do
      Phoenix.LiveView.get_connect_params(socket)["_csrf_token"]
      |> encrypt_csrf_into_ets()

      :ok = WsWeb.Endpoint.subscribe("price")

      symbol = "bitcoin"

      DynamicSupervisor.start_child(DynSup, {
        Ws.ClientWebsocketHandler,
        uri: "wss://ws.coincap.io/prices?assets=" <> symbol, state: %{symbol: symbol}
      })
    end

    {:ok,
     socket
     |> assign(%{user_token: user_token, image_base64: nil, blob_size: nil, encoded_len: nil, b64_data: nil})}
  end

  @impl true
  def handle_event("send_as_base64", params, socket) do
    %{"data_as_b64" => bin, "blob_size" => blob_size, "string_length" => encoded_len} = params

    {:noreply,
     socket
     |> assign(%{image_base64: bin, blob_size: blob_size, encoded_len: encoded_len})}
  end

  def handle_event("produce-base64", _, socket) do
    {:noreply,
     socket
     |> assign(:b64_data, fetch_image_as_base64())}
  end

  @impl true
  def handle_info(%{topic: "price", event: "new", payload: %{value: value}}, socket) do
    {:noreply, push_event(socket, "new", %{value: value})}
  end

  defp fetch_image_as_base64,
    do:
      Req.get!("https://picsum.photos/300/300").body
      |> Base.encode64()
end
