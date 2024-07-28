export const rawWebSocketHook = {
  mounted() {
    let protocole = window.location.protocol.includes("https") ? "wss" : "ws";

    let url = "https://picsum.photos/300/300.jpg",
      timerId = 0,
      reconnectTimeout = 1_000,
      ws;

    function connect() {
      if (ws) ws.close();

      ws = new WebSocket(
        `${protocole}://${window.location.host}/rawsocket?token=${window.userToken}`
      );

      const sendButton = document.getElementById("send-via-ws");
      const requestButton = document.getElementById("request-data-from-ws");

      ws.onopen = () => {
        console.log("Raw WS Connected to the server");
        requestButton.disabled = false;
        clearInterval(timerId);
        startPing();
      };

      requestButton.onclick = () => ws.send("request-from-server");

      let imageChunks = [],
        totalChunks = 0;

      ws.onmessage = ({ data }) => {
        if (data instanceof Blob) {
          receiveViaWs(data, "from-server-via-ws");
        } else {
          console.log(data);
        }
      };

      sendButton.onclick = () => sendPicViaWs();

      function sendPicViaWs() {
        fetch(url).then((response) => {
          response.blob().then((blob) => {
            document.getElementById("display-img-sent-to-server-via-ws").src =
              URL.createObjectURL(blob);
            blob.arrayBuffer().then((arrayBuffer) => {
              ws.send(arrayBuffer);
            });
          });
        });
      }

      function receiveViaWs(data, picId) {
        if (data instanceof Blob) {
          console.log("WS received a pic", Math.round(data.size / 1000), "KB");
          let blob = new Blob([data], { type: "image/jpeg" });
          let imageUrl = URL.createObjectURL(blob);
          document.getElementById(picId).src = imageUrl;
        } else {
          console.log("WS received a message :", data);
        }
      }

      ws.onclose = () => {
        console.log("Disconnected from the server");

        timerId = setTimeout(() => connect(), reconnectTimeout);
        reconnectTimeout = Math.min(reconnectTimeout * 2, 30_000);
      };

      ws.onerror = (error) => {
        console.error("Error", error);
        stopPing();
      };

      let pingId = 0;

      function startPing() {
        pingInterval = setInterval(() => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send("ping");
          }
        }, 30_000); // send ping every 30 seconds
      }

      function stopPing() {
        clearInterval(pingId);
      }
    }

    connect();
  },
};
