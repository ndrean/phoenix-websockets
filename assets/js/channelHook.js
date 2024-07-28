import userSocket from "./userSocket.js";
import useChannel from "./useChannel.js";

export const channelHook = {
  mounted() {
    let imageChannel, imageURL;

    async function setImageChannel() {
      imageChannel = await useChannel(userSocket, "image");

      imageChannel.on("image-saved-to-disk", () =>
        console.log("Channel: saved to disk")
      );

      let imageChunks = [],
        totalChunks = 0;

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
    }

    setImageChannel();

    document.getElementById("request-data-from-channel").onclick = () =>
      imageChannel.push("request-image");

    document.getElementById("send-via-channel").onclick = async () => {
      sendPicToServerViaChannel(
        imageChannel,
        "display-img-sent-to-server-via-ch"
      );
      await sendLargeFileViaChannel(imageChannel);
    };

    function sendPicToServerViaChannel(channel, picId) {
      let url = "https://picsum.photos/300/300.jpg";
      fetch(url).then((response) => {
        response.blob().then((blob) => {
          document.getElementById(picId).src = URL.createObjectURL(blob);
          blob.arrayBuffer().then((arrayBuffer) => {
            channel.push("pic-to-server", arrayBuffer);
          });
        });
      });
    }

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

    /*
      imageChannel.on("image-received", (payload) =>
        displayReceivedMsg(payload, "image-received", "from-server-via-channel")
      );

      function displayReceivedMsg(payload, topic, picId) {
        console.log("displayReceivedMsg");
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
      */
  },
};
