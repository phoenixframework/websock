defmodule WebSock do
  @moduledoc """
  Defines a behaviour which defines an interface for web servers to flexibly host WebSocket
  applications. Also provides a consistent upgrade facility to upgrade `Plug.Conn` requests to 
  `WebSock` connections for supported servers.

  WebSocket connections go through a well defined lifecycle mediated by `WebSock`:

  * **This step is outside the scope of the WebSock API**. A client will
  attempt to Upgrade an HTTP connection to a WebSocket connection by passing
  a specific set of headers in an HTTP request. An application may choose to
  determine the feasibility of such an upgrade request however it pleases
  * An application will then signal an upgrade to be performed by calling `WebSock.upgrade/4`, passing
  in the `Plug.Conn` to upgrade, along with the `WebSock` compliant handler module which
  will handle the connection once it is upgraded
  * The underlying server will then attempt to upgrade the HTTP connection to a WebSocket connection 
  * Assuming the WebSocket connection is successfully negotiated, WebSock will
  call `c:WebSock.init/1` on the configured handler to allow the application to perform any necessary
  tasks now that the WebSocket connection is live
  * WebSock will call the configued handler's `c:WebSock.handle_in/2` callback
  whenever data is received from the client
  * WebSock will call the configued handler's `c:WebSock.handle_info/2` callback
  whenever other processes send messages to the handler process
  * The `WebSock` implementation can send data to the client by returning
  a `{:push,...}` tuple from any of the above `handle_*` callback
  * At any time, `c:WebSock.terminate/2` may be called to indicate a close, error or
  timeout condition 
  """

  @typedoc "The type of an implementing module"
  @type impl :: module()

  @typedoc "The type of state passed into / returned from `WebSock` callbacks"
  @type state :: term()

  @typedoc "The type of a supported connection option"
  @type connection_opt ::
          {:compress, boolean()}
          | {:timeout, timeout()}
          | {:max_frame_size, non_neg_integer()}
          | {:fullsweep_after, non_neg_integer()}

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
  Called by WebSock after a WebSocket connection has been established (that is, after the server
  has accepted the connection & the WebSocket handshake has been successfully completed).
  Implementations can use this callback to perform tasks such as subscribing the client to any
  relevant subscriptions within the application, or any other task which should be undertaken at
  the time the connection is established

  The return value from this callback is handled as described in `c:handle_in/2`
  """
  @callback init(term()) :: handle_result()

  @doc """
  Called by WebSock when a frame is received from the client. WebSock will only call this function
  once a complete frame has been received (that is, once any continuation frames have been
  received).

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
  Called by WebSock when a ping or pong frame has been received from the client. Note that
  implementations SHOULD NOT send a pong frame in response; this MUST be automatically done by the
  web server before this callback has been called.

  Despite the name of this callback, it is not called for connection close frames even though they
  are technically control frames. WebSock will handle any received connection
  close frames and issue calls to `c:terminate/2` as / if appropriate

  This callback is optional

  The return value from this callback is handled as described in `c:handle_in/2`
  """
  @callback handle_control({message(), opcode: control_opcode()}, state()) :: handle_result()

  @doc """
  Called by WebSock when the socket process receives a `c:GenServer.handle_info/2` call which was
  not otherwise processed by the server implementation.

  The return value from this callback is handled as described in `c:handle_in/2`
  """
  @callback handle_info(term(), state()) :: handle_result()

  @doc """
  Called by WebSock when a connection is closed. `reason` may be one of the following:

  * `:normal`: The local end shut down the connection normally, by returning a `{:stop, :normal,
    state()}` tuple from one of the `WebSock.handle_*` callbacks
  * `:remote`: The remote end shut down the connection
  * `:shutdown`: The local server is being shut down
  * `:timeout`: No data has been sent or received for more than the configured timeout duration
  * `{:error, reason}`: An error ocurred. This may be the result of error
    handling in the local server, or the result of a `WebSock.handle_*` callback returning a `{:stop,
    reason, state}` tuple where reason is any value other than `:normal`

  The return value of this callback is ignored
  """
  @callback terminate(reason :: close_reason(), state()) :: any()

  @optional_callbacks handle_control: 2

  @doc """
  Upgrades the provided `Plug.Conn` connection request to a `WebSock` connection using the
  provided `WebSock` compliant module as a handler.

  This function returns the passed `conn` set to an `:upgraded` state.

  The provided `state` value will be used as the argument for `c:init/1` once the WebSocket
  connection has been successfully negotiated.

  The `opts` keyword list argument allows a number of options to be set on the WebSocket
  connection. Not all options may be supported by the underlying HTTP server. Possible values are
  as follows:

  * `timeout`: The number of milliseconds to wait after no client data is received before
   closing the connection. Defaults to `60_000`
  * `compress`: Whether or not to accept negotiation of a compression extension with the client.
   Defaults to `false`
  * `max_frame_size`: The maximum frame size to accept, in octets. If a frame size larger than this
   is received the connection will be closed. Defaults to `:infinity`
  * `:fullsweep_after`: The maximum number of garbage collections before forcing a fullsweep of
   the WebSocket connection process. Setting this option requires OTP 24 or newer
  """
  @spec upgrade(Plug.Conn.t(), impl(), state(), [connection_opt()]) :: Plug.Conn.t()
  def upgrade(%{adapter: {adapter, _}} = conn, websock, state, opts) do
    Plug.Conn.upgrade_adapter(conn, :websocket, tuple_for(adapter, websock, state, opts))
  end

  defp tuple_for(Bandit.HTTP1.Adapter, websock, state, opts), do: {websock, state, opts}
  defp tuple_for(Bandit.HTTP2.Adapter, websock, state, opts), do: {websock, state, opts}

  defp tuple_for(Plug.Cowboy.Conn, websock, state, opts) do
    cowboy_opts =
      opts
      |> Enum.flat_map(fn
        {:timeout, timeout} -> [idle_timeout: timeout]
        {:compress, _} = opt -> [opt]
        {:max_frame_size, _} = opt -> [opt]
        _other -> []
      end)
      |> Map.new()

    process_flags =
      opts
      |> Keyword.take([:fullsweep_after])
      |> Map.new()

    {WebSock.CowboyAdapter, {websock, process_flags, state}, cowboy_opts}
  end

  defp tuple_for(adapter, _websock, _state, _opts),
    do: raise(ArgumentError, "Unknown adapter #{inspect(adapter)}")
end
