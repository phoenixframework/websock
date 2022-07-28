defprotocol Sock.Socket do
  @moduledoc """
  A protocol to provide the ability for `Sock` implementations to send data to a connected
  WebSocket client. An instance of an (otherwise opaque) type conforming to this protocol is
  passed in to `Sock` implementations as the first argument of most `Sock` callbacks.
  """

  @doc """
  Sends the specified data to the client as a text frame(s).

  An implementation is permitted to send this data as one or more text / continuation frames at
  its discretion.
  """
  @spec send_text_frame(socket :: t(), data :: binary()) :: :ok
  def send_text_frame(socket, data)

  @doc """
  Sends the specified data to the client as a binary frame(s).

  An implementation is permitted to send this data as one or more binary / continuation frames at
  its discretion.
  """
  @spec send_binary_frame(socket :: t(), data :: binary()) :: :ok
  def send_binary_frame(socket, data)

  @doc """
  Sends the data to the client within a ping frame.
  """
  @spec send_ping_frame(socket :: t(), data :: binary()) :: :ok
  def send_ping_frame(socket, data)

  @doc """
  Sends the data to the client within a pong frame. Note that `Sock` implementation should not
  send pong frames in response to ping frames on their own, since the backing implementation is expected
  to do this automatically. This function is present solely for purpose of proactively sending
  pong frames as a unidirectional heartbeat per RFC6455§5.3.3.
  """
  @spec send_pong_frame(socket :: t(), data :: binary()) :: :ok
  def send_pong_frame(socket, data)
end
