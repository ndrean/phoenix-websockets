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
    };

    document.getElementById("download-big-file").onclick = async () =>
      await sendLargeFileViaChannel(imageChannel);

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

      while (true) {
        const { done, value } = await reader.read();

        if (done) {
          console.log("Transfer completed");
          break;
        }

        receivedLength += value.length;

        channel.push("chunk", value.buffer);

        console.log(`Received ${receivedLength} of ${contentLength} bytes`);
      }
    };
  },
};
