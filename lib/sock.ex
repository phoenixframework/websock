defmodule Sock do
  @moduledoc """
  The `Sock` behaviour defines an interface for web servers to flexibly host WebSocket
  applications.

  The lifecycle of a WebSocket connection is codified in the structure of this behaviour, and
  proceeds as follows:

  * **This step is outside the scope of the Sock API**. A client will
    attempt to Upgrade an HTTP connection to a WebSocket connection by passing
    a specific set of headers in an HTTP request. An application may choose to
    determine the feasibility of the upgrade request however it pleases, though
    the `Plug.WebSocket` module includes several conveniences for this purpose.
    Most typically, an application will then signal an upgrade to be performed by
    calling the `Plug.Conn.upgrade_adapter/3` callback with parameters indicating
    an upgrade to Sock (note that the structure of these arguments depends on the
    particular server in use; consult `Bandit` or `Plug.Cowboy` documentation for
    details)
  * Assuming the application accepted the WebSocket connection, the underlying
    server will then upgrade the HTTP connection to a WebSocket connection, and
    will call `c:Sock.init/1` to allow the application to perform any necessary
    tasks now that the WebSocket connection is live
  * The `Sock` implementation will be notified of client data by way of the
    `c:Sock.handle_in/2` callback
  * The `Sock` implementation may choose to be notified of control frames by way of the
    optional `c:Sock.handle_control/2` callback. Note that user implementations DO
    NOT need to concern themselves with issuing pong frames in response to ping
    requests; the underlying server implementation MUST handle this
  * The `Sock` implementation will be notified of any messages sent to it by
    other processes by way of the `c:Sock.handle_info/2` callback
  * The `Sock` implementation can send data to the client by returning
    a `{:push, ...}` or `{:reply, ...}` tuple from any of the above `handle_*` callback
  * At any time, `c:Sock.terminate/2` may be called to indicate a close, error or
    timeout condition 
  """

  @typedoc "The type of an implementing module"
  @type impl :: module()

  @typedoc "The type of state passed into / returned from `Sock` callbacks"
  @type state :: term()

  @typedoc "The structure of a sent or received WebSocket message body"
  @type message :: iodata() | nil

  @typedoc "Possible data frame types"
  @type data_opcode :: :text | :binary

  @typedoc "Possible control frame types"
  @type control_opcode :: :ping | :pong

  @typedoc "All possible frame types"
  @type opcode :: data_opcode() | control_opcode()

  @typedoc "The result as returned from init, handle_in, handle_control & handle_info calls"
  @type handle_result ::
          {:push, {opcode(), message()}, state()}
          | {:reply, term(), {opcode(), message()}, state()}
          | {:ok, state()}
          | {:stop, term(), state()}

  @typedoc "Details about why a connection was closed"
  @type close_reason :: :normal | :remote | :shutdown | :timeout | {:error, term()}

  @doc """
  Called by the web server implementation after a WebSocket connection has been established (that
  is, after the server has accepted the connection & the WebSocket handshake has been
  successfully completed). Implementations can use this callback to perform tasks such as
  subscribing the client to any relevant subscriptions within the application, or any other
  task which should be undertaken at the time the connection is established

  The return value from this callback is handled as described in `c:handle_in/2`
  """
  @callback init(term()) :: handle_result()

  @doc """
  Called by the web server implementation when a frame is received from the client. The server
  implementation will only call this function once a complete frame has been received (that is,
  once any continuation frames have been received).

  The return value from this callback are processed as follows:

  * `{:push, {opcode(), message()}, state()}`: The indicated message is sent to the client. The
    indicated state value is used to update the socket's current state
  * `{:reply, term(), {opcode(), message()}, state()}`: The indicated message is sent to the client. The
    indicated state value is used to update the socket's current state. The second element of the
    tuple has no semantic meaning in this context and is ignored. This return tuple is included
    here solely for backwards compatiblity with the `Phoenix.Socket.Transport` behaviour; it is in
    all respects semantically identical to the `{:push, ...}` return value previously described
  * `{:ok, state()}`: The indicated state value is used to update the socket's current state
  * `{:stop, reason :: term(), state()}`: The connection will be closed based on the indicated
    reason. If `reason` is `:normal`, `c:terminate/2` will be called with a `reason` value of
    `:normal`. In all other cases, it will be called with `{:error, reason}`. Server
    implementations should also use this value when determining how to close the connection with
    the client
  """
  @callback handle_in({message(), opcode: data_opcode()}, state()) :: handle_result()

  @doc """
  Called by the web server implementation when a ping or pong frame has been received from the client.
  Note that `Sock` implementation SHOULD NOT send a pong frame in response; this MUST be
  automatically done by the web server before this callback has been called.

  Despite the name of this callback, it is not called for connection close frames even though they
  are technically control frames. The server implementation will handle any received connection
  close frames and issue calls to `c:terminate/2` as / if appropriate

  This callback is optional

  The return value from this callback is handled as described in `c:handle_in/2`
  """
  @callback handle_control({message(), opcode: control_opcode()}, state()) :: handle_result()

  @doc """
  Called by the web server implementation when the socket process receives
  a `c:GenServer.handle_info/2` call which was not otherwise processed by the server
  implementation.

  The return value from this callback is handled as described in `c:handle_in/2`
  """
  @callback handle_info(term(), state()) :: handle_result()

  @doc """
  Called by the web server implementation when a connection is closed. `reason` may be one of the
  following:

  * `:normal`: The local end shut down the connection normally, by returning a `{:stop, :normal,
    state()}` tuple from one of the `Sock.handle_*` callbacks
  * `:remote`: The remote end shut down the connection
  * `:shutdown`: The local server is being shut down
  * `:timeout`: No data has been sent or received for more than the configured timeout duration
  * `{:error, reason}`: An error ocurred. This may be the result of error
    handling in the local server, or the result of a `Sock.handle_*` callback returning a `{:stop,
    reason, state}` tuple where reason is any value other than `:normal`

  The return value of this callback is ignored
  """
  @callback terminate(reason :: close_reason(), state()) :: any()

  @optional_callbacks handle_control: 2
end
