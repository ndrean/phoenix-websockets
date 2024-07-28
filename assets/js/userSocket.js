import { Socket } from "phoenix";

const userSocket = new Socket("/userSocket", {
  params: { userToken: window.userToken },
});
userSocket.connect();

export default userSocket;
