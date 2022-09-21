defmodule Sock do
  @moduledoc """
  The `Sock` behaviour defines an interface for web servers to flexibly host WebSocket
  applications.

  The lifecycle of a WebSocket connection is codified in the structure of this behaviour, and
  proceeds as follows:

  * First, a client will attempt to Upgrade an HTTP connection to a WebSocket
    connection by passing a specific set of headers in an HTTP request. A `Sock`
    implementation is notified of this via a call to `c:Sock.negotiate/2`. The
    implementation can inspect the request, which is passed as a `Plug.Conn`
    structure. It can then choose to accept or refuse the WebSocket upgrade
    request
  * Assuming the `Sock` implementation accepted the WebSocket connection, the
    HTTP connection is then upgraded to a WebSocket connection, and
    `c:Sock.handle_connection/2` is called to notify the implementation that the
    connection is now live
  * The `Sock` implementation will then be notified of client data by way of
    `c:Sock.handle_text_frame/3`, `c:Sock.handle_binary_frame/3`,
    `c:Sock.handle_ping_frame/3` or `c:Sock.handle_pong_frame/3` as appropriate.
  * The `Sock` implementation is free to send data to the client via the passed in
    `Socket` instance at any time
  * At any time, `c:Sock.handle_close/3`, `c:Sock.handle_error/3` or
    `c:Sock.handle_timeout/2` may be called to indicate a close, error or timeout
    condition respectively
  * All of the above callbacks take and return a state value, in a manner similar to GenServers.
  * The initial value of this state is that returned from the `c:init/1` callback
  """

  @typedoc "The type of state passed into / returned from `Sock` callbacks"
  @type state :: term()

  @typedoc """
  The type of options returned from the `c:negotiate/2` callback. Possible values have the
  following meanings:

  * `timeout`: Specifies a value to be used for timeout conditions on this connection
  """
  @type negotiate_opts :: {:timeout, timeout()}

  @typedoc "The result as returned from negotiate calls"
  @type negotiate_result ::
          {:accept, Plug.Conn.t(), state(), [negotiate_opts()]}
          | {:refuse, Plug.Conn.t(), state()}

  @typedoc "The result as returned from many handle_ calls"
  @type handle_result :: {:continue, state()} | {:close, state()} | {:error, term(), state()}

  @typedoc "A WebSocket status code"
  @type status_code :: non_neg_integer()

  @typedoc "Details about why connection is being closed"
  @type close_reason :: {:local, status_code()} | {:remote, status_code()}

  @doc """
  Called by a web server implementation to provide initial state for all future connections. The
  manner by which the user specifies the `init_arg` value passed into this callback is
  implementation dependent.

  The result returned by init/1 is used as the initial state of all connections using the `Sock`
  implementation. Note that init/1 may be called during compilation and as such it must not return
  pids, ports or values that are specific to the runtime.
  """
  @callback init(init_arg :: term()) :: state()

  @doc """
  Called by the web server implementation when a client attempts to upgrade to a WebSocket
  connection. At this point, the web server has validated that the upgrade request is technically
  correct (that is, it meets all the requirements laid out in RFC6455§4.1), but this callback is
  provided in case the `Sock` implementation wishes to perform further checks before accepting the
  connection (perhaps by considering the request path or various headers). 

  This call is also the last time that the originating request is accessible by the `Sock`
  implementation. Should values from the `Plug.Conn` request be needed later on in the WebSocket
  lifecycle, this callback should store such values in the returned connection state.

  If the `Sock` implementation wishes to accept this connection, it should return a `{:accept,
  Plug.Conn.t(), state(), [opts()]}` tuple. The web server will then perform its half of the
  connection handshake as outlined in RFC6455§4.2, and subsequently call `c:handle_connection/2`.
  The `Sock` implementation MUST NOT send any data on the `Plug.Conn` connection in this case, or
  else the handshake will not be able to complete.

  Valid options to return in the final `accept` tuple value are as described in the
  `t:negotiate_opts()` type.

  If the `Sock` implementation wishes to refuse this connection, it should:
    * Create an HTTP response on the `Plug.Conn` connection describing the reason for refusal
    * Return a `{:refuse, Plug.Conn.t(), state()}` tuple with the updated conn as a second
      argument
  """
  @callback negotiate(conn :: Plug.Conn.t(), state()) :: negotiate_result()

  @doc """
  Called by the web server implementation after a WebSocket connection has been established (that
  is, after `c:negotiate/2` has accepted the connection & the WebSocket handshake has been
  successfully completed). Implementations can use this callback to eagerly send data to the
  client, subscribe the client to any relevant subscriptions within the application, or any other
  task which should be undertaken at the time the connection is established

  The return value from this callback is handled as follows:

  * `{:continue, state()}`: The connection is kept open & its state is updated to the returned
    value
  * `{:close, state()}`: The connection is closed cleanly & its state is updated to the returned
    value. `c:handle_close/3` will be subsequently called a reason code of 1000 & the updated state
  * `{:error, term(), state()}`: The connection is closed  abnormally & its state is updated to
    the returned value. `c:handle_error/3` will be subsequently called with the updated state
  """
  @callback handle_connection(Sock.Socket.t(), state()) :: handle_result()

  @doc """
  Called by the web server implementation when text data is received from the client. The web
  server implementation will only call this function once a complete text frame has been received
  (that is, once any continuation frames have been received).

  The return value from this callback is handled as described in `c:handle_connection/2`
  """
  @callback handle_text_frame(binary(), Sock.Socket.t(), state()) :: handle_result()

  @doc """
  Called by the web server implementation when binary data is received from the client. The web
  server implementation will only call this function once a complete binary frame has been received
  (that is, once any continuation frames have been received).

  The return value from this callback is handled as described in `c:handle_connection/2`
  """
  @callback handle_binary_frame(binary(), Sock.Socket.t(), state()) :: handle_result()

  @doc """
  Called by the web server implementation when a ping frame has been received from the client.
  Note that `Sock` implementation SHOULD NOT send a pong frame in response; this MUST be
  automatically done by the web server before this callback has been called.

  The return value from this callback is handled as described in `c:handle_connection/2`
  """
  @callback handle_ping_frame(binary(), Sock.Socket.t(), state()) :: handle_result()

  @doc """
  Called by the web server implementation when a pong frame has been received from the client.

  The return value from this callback is handled as described in `c:handle_connection/2`
  """
  @callback handle_pong_frame(binary(), Sock.Socket.t(), state()) :: handle_result()

  @doc """
  Called by the web server implementation when a connection is being closed due to one of the
  following reasons:

  * A `Sock` callback for this connection returned a `{:close, state()}` tuple. The reason will
    be `{:local, 1000}`. The socket connection will still be open in this case
  * The hosting web server is being shut down. The reason will be `{:local, 1001}`. The socket
    connection will still be open in this case
  * The client send a connection close frame. The reason will be `{:remote, code}`, where `code`
    is the status code sent by the client (or 1005 is no status code was sent). The socket
    connection will still be open in this case, although care should be taken of the fact that
    the client may not be listening any longer

  The return value from this callback is ignored
  """
  @callback handle_close(close_reason(), Sock.Socket.t(), state()) :: any()

  @doc """
  Called by the web server implementation when a connection is being closed due to one of the
  following reasons:

  * A `Sock` callback for this connection returned an `{:error, reason, state()}` tuple. The 
    socket connection will still be open in this case
  * The underlying TCP connection was closed unexpectedly. The socket connection will be closed
    in this case
  * The underlying TCP connection connection encountered an error. The socket connection will be
    closed in this case

  The return value from this callback is ignored
  """
  @callback handle_error(term(), Sock.Socket.t(), state()) :: any()

  @doc """
  Called by the web server implementation when a connection has not received any client data for
  a period of time. The exact details of what this means and any particular timeout values are
  dependent on the underlying web server implementation. The socket connection will be open in
  this case.

  The return value from this callback is ignored
  """
  @callback handle_timeout(Sock.Socket.t(), state()) :: any()

  @doc """
  Called by the web server implementation when the socket process receives
  a `c:GenServer.handle_info/2` call which was not otherwise processed by the server
  implementation.

  The return value from this callback is handled as described in `c:handle_connection/2`
  """
  @callback handle_info(term(), Sock.Socket.t(), state()) :: handle_result()
end
