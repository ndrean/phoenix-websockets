export const pushHook = {
  mounted() {
    const directImg = document.getElementById("direct-browser-fetch");

    const directRender = (img, blob) => {
      img.src = URL.createObjectURL(blob);
    };

    const sendBase64ViaLiveSocket = (blob) => {
      const reader = new FileReader();
      reader.readAsDataURL(blob);
      reader.onload = () => {
        this.pushEvent("send_as_base64", {
          data_as_b64: reader.result,
          blob_size: blob.size,
          string_length: reader.result.length,
        });
      };
    };

    const sendImageAsB64 = async () => {
      let url = "https://picsum.photos/300/300.jpg";
      const response = await fetch(url);
      const blob = await response.blob();

      directRender(directImg, blob);
      sendBase64ViaLiveSocket(blob);
    };

    sendImageAsB64();
  },
};
