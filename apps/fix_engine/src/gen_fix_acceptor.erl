-module(gen_fix_acceptor).

-include("fix_engine_config.hrl").
-include("fix_parser.hrl").
-include("fix_fields.hrl").

-behaviour(gen_server).

-export([set_socket/2, connect/1, disconnect/1]).

-export([start_link/1, init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([apply/2, 'DISCONNECTED'/2, 'CONNECTED'/2, 'LOGGED_IN'/2]).

-record(data, {session_id, socket = undef, useTracer = false, parser, seq_num_out = 1, se_num_in = 1, senderCompID, targetCompID, username,
      password, state = 'DISCONNECTED', heartbeat_int, timer_ref = undef, binary = <<>>}).

set_socket(SessionPid, Socket) ->
   gen_tcp:controlling_process(Socket, SessionPid),
   gen_server:call(SessionPid, {gen_fix_acceptor, {set_socket, Socket}}).

connect(SessionID) ->
   gen_server:call(SessionID, {gen_fix_acceptor, connect}).

disconnect(SessionID) ->
   gen_server:call(SessionID, {gen_fix_acceptor, disconnect}).

start_link(Args = #fix_session_acceptor_config{senderCompID = SenderCompID, targetCompID = TargetCompID}) ->
   SessionID = fix_utils:make_session_id(SenderCompID, TargetCompID),
   error_logger:info_msg("Starting acceptor session [~p].", [SessionID]),
   gen_server:start_link({local, SessionID}, ?MODULE, Args, []).

init(#fix_session_acceptor_config{fix_protocol = Protocol, fix_parser_flags = ParserFlags, senderCompID = SenderCompID, targetCompID = TargetCompID,
      username = Username, password = Password, useTracer = UseTracer}) ->
   case fix_parser:create(Protocol, [], ParserFlags) of
      {ok, ParserRef} -> error_logger:info_msg("Parser [~p] has been created.", [fix_parser:get_version(ParserRef)]);
      {error, ParserRef} -> exit({fix_parser_error, ParserRef})
   end,
   SessionID = fix_utils:make_session_id(SenderCompID, TargetCompID),
   print_use_tracer(SessionID, UseTracer),
   {ok, #data{session_id = SessionID, parser = ParserRef, senderCompID = SenderCompID, targetCompID = TargetCompID,
         username = Username, password = Password, useTracer = UseTracer}}.

handle_call({gen_fix_acceptor, Msg}, _From, Data) ->
   {ok, NewData} = ?MODULE:apply(Data, Msg),
   {reply, ok, NewData};
handle_call(_Msg, _From, Data) ->
   % TODO: will call derived module
   {reply, ok, Data}.

handle_cast(_Request, Data) ->
   % TODO: will call derived module
   {noreply, Data}.

handle_info({tcp, Socket, <<>>}, Data = #data{socket = Socket}) ->
   {noreply, Data};
handle_info({tcp, Socket, Bin}, Data = #data{socket = Socket, binary = PrefixBin}) ->
   case fix_parser:str_to_msg(Data#data.parser, ?FIX_SOH, <<PrefixBin/binary, Bin/binary>>) of
      {ok, Msg, RestBin} ->
         trace(Msg, in, Data),
         Data1 = Data#data{binary = <<>>},
         {ok, Data2} = ?MODULE:apply(Data1, Msg),
         {noreply, NewData} = handle_info({tcp, Socket, RestBin}, Data2);
      {error, ?FIX_ERROR_BODY_TOO_SHORT, _} ->
         NewData = Data#data{binary = <<PrefixBin/binary, Bin/binary>>};
      {error, ErrCode, ErrText} ->
         error_logger:error_msg("Unable to parse incoming message. Error = [~p], Description = [~p].", [ErrCode,
               ErrText]),
         {ok, NewData} = ?MODULE:apply(Data, {parse_error, ErrCode, ErrText})
   end,
   if erlang:is_port(NewData#data.socket) -> inet:setopts(Socket, [{active, once}]);
      true -> ok
   end,
   {noreply, NewData};
handle_info({tcp_closed, Socket}, Data = #data{socket = Socket}) ->
   {ok, NewData} = ?MODULE:apply(Data, tcp_closed),
   {noreply, NewData};
handle_info(_Info, Data) ->
   % TODO: will call derived module
   {noreply, Data}.

terminate(_Reason, _Data) ->
   ok.

code_change(_OldVsn, Data, _Extra) ->
   {ok, Data}.

% =====================================================================================================
% =========================== Acceptor FSM begin ======================================================
% =====================================================================================================

'DISCONNECTED'(connect, Data) ->
   {ok, Data#data{state = 'CONNECTED'}}.

'CONNECTED'({set_socket, Socket}, Data) ->
   {ok, Data#data{socket = Socket}};

'CONNECTED'(disconnect, Data) ->
   {ok, Data#data{state = 'DISCONNECTED'}};

'CONNECTED'(Msg = #msg{type = "A"}, Data = #data{socket = Socket, state = 'CONNECTED'}) ->
   error_logger:info_msg("~p: logon received.", [Data#data.session_id]),
   try
      validate_logon(Msg, Data#data.username, Data#data.password),
      {ok, HeartBtInt} = fix_parser:get_int32_field(Msg, ?FIXFieldTag_HeartBtInt),
      {ok, ResetSeqNum} = fix_parser:get_char_field(Msg, ?FIXFieldTag_ResetSeqNumFlag, $N),
      SeqNumOut = if ResetSeqNum == $Y -> 1; true -> Data#data.seq_num_out end,
      NewData = Data#data{socket = Socket, seq_num_out = SeqNumOut, heartbeat_int = HeartBtInt * 1000},
      LogonReply = create_logon(Data#data.parser, HeartBtInt, ResetSeqNum),
      send_fix_message(LogonReply, NewData),
      inet:setopts(Socket, [{active, once}]),
      {ok, NewData#data{state = 'LOGGED_IN', seq_num_out = SeqNumOut + 1, timer_ref = restart_heartbeat(NewData)}}
   catch
      throw:{badmatch, {error, _, Reason}} ->
         LogoutMsg = create_logout(Data#data.parser, Reason),
         send_fix_message(LogoutMsg, Data),
         gen_tcp:close(Socket),
         {ok, Data#data{state = 'CONNECTED'}};
      throw:{error, Reason} ->
         LogoutMsg = create_logout(Data#data.parser, Reason),
         send_fix_message(LogoutMsg, Data),
         gen_tcp:close(Socket),
         {ok, Data#data{state = 'CONNECTED'}};
      _:Err ->
         error_logger:error_msg("Logon failed: ~p", [Err]),
         LogoutMsg = create_logout(Data#data.parser, "Logon failed"),
         send_fix_message(LogoutMsg, Data),
         gen_tcp:close(Socket),
         {ok, Data#data{state = 'CONNECTED'}}
   end.

'LOGGED_IN'({timeout, _, heartbeat}, Data) ->
   {ok, Msg} = fix_parser:create_msg(Data#data.parser, "0"),
   send_fix_message(Msg, Data),
   TimerRef = erlang:start_timer(Data#data.heartbeat_int, self(), heartbeat),
   {ok, Data#data{seq_num_out = Data#data.seq_num_out + 1, timer_ref = TimerRef}};

'LOGGED_IN'(disconnect, Data) ->
   Msg = create_logout(Data#data.parser, "Explicitly disconnected"),
   send_fix_message(Msg, Data),
   gen_tcp:close(Data#data.socket),
   {ok, Data#data{socket = undef, seq_num_out = Data#data.seq_num_out + 1, state = 'CONNECTED'}};

'LOGGED_IN'(tcp_closed, Data) ->
   {ok, Data#data{socket = undef, state = 'CONNECTED'}};

'LOGGED_IN'(#msg{type = "0"}, Data) ->
   {ok, Data};

'LOGGED_IN'(#msg{type = "5"}, Data) ->
   Logout = create_logout(Data#data.parser, "Bye"),
   send_fix_message(Logout, Data),
   {ok, Data#data{seq_num_out = Data#data.seq_num_out + 1, timer_ref = undef}};

'LOGGED_IN'(TestRequestMsg = #msg{type = "1"}, Data = #data{seq_num_out = SeqNumOut}) ->
   {ok, TestReqID} = fix_parser:get_string_field(TestRequestMsg, ?FIXFieldTag_TestReqID),
   {ok, HeartbeatMsg} = fix_parser:create_msg(Data#data.parser, "0"),
   ok = fix_parser:set_string_field(HeartbeatMsg, ?FIXFieldTag_TestReqID, TestReqID),
   send_fix_message(HeartbeatMsg, Data),
   {ok, Data#data{seq_num_out = SeqNumOut + 1, timer_ref = restart_heartbeat(Data)}}.

% =====================================================================================================
% =========================== Acceptor FSM end ========================================================
% =====================================================================================================

apply(Data = #data{session_id = SessionID, state = OldState}, Msg) ->
   case (catch erlang:apply(?MODULE, OldState, [Msg])) of
      {ok, NewData = #data{state = NewState}} ->
         if NewState =/= OldState -> error_logger:info_msg("[~p] state changed [~p]->[~p].", [SessionID, OldState, NewState]); true -> ok end,
         {ok, NewData};
      {'EXIT', {function_clause, [_]}} ->
         error_logger:warning_msg("Unsupported session [~p] state [~p] message [~p].", [SessionID, OldState, Msg]),
         {ok, Data};
      Other ->
         error_logger:error_msg("Wrong call [~p]", [Other]),
         exit({error_wrong_result, Other})
   end.

restart_heartbeat(#data{timer_ref = undef, heartbeat_int = Timeout}) ->
   erlang:start_timer(Timeout, self(), heartbeat);
restart_heartbeat(#data{timer_ref = OldTimerRef, heartbeat_int = Timeout}) ->
   erlang:cancel_timer(OldTimerRef),
   erlang:start_timer(Timeout, self(), heartbeat).

validate_logon(Msg = #msg{type = "A"}, Username, Password) ->
   {ok, Username1} = fix_parser:get_string_field(Msg, ?FIXFieldTag_Username, ""),
   {ok, Password1} = fix_parser:get_string_field(Msg, ?FIXFieldTag_Password, ""),
   if ((Username == Username1) orelse (Password == Password1)) -> ok;
      true ->
         throw({error, "Wrong Username/Password"})
   end;
validate_logon(_, _, _) ->
   throw({error, "Not a logon message"}).

create_logout(Parser, Text) ->
   {ok, Msg} = fix_parser:create_msg(Parser, "5"),
   ok = fix_parser:set_string_field(Msg, ?FIXFieldTag_Text, Text),
   Msg.

create_logon(Parser, HeartBtInt, ResetSeqNum) ->
   {ok, Msg} = fix_parser:create_msg(Parser, "A"),
   ok = fix_parser:set_int32_field(Msg, ?FIXFieldTag_HeartBtInt, HeartBtInt),
   ok = fix_parser:set_char_field(Msg, ?FIXFieldTag_ResetSeqNumFlag, ResetSeqNum),
   ok = fix_parser:set_int32_field(Msg, ?FIXFieldTag_EncryptMethod, 0),
   Msg.

send_fix_message(Msg, Data) ->
   ok = fix_parser:set_string_field(Msg, ?FIXFieldTag_SenderCompID, Data#data.senderCompID),
   ok = fix_parser:set_string_field(Msg, ?FIXFieldTag_TargetCompID, Data#data.targetCompID),
   ok = fix_parser:set_int32_field(Msg, ?FIXFieldTag_MsgSeqNum, Data#data.seq_num_out),
   ok = fix_parser:set_string_field(Msg, ?FIXFieldTag_SendingTime, fix_utils:now_utc()),
   {ok, BinMsg} = fix_parser:msg_to_str(Msg, ?FIX_SOH),
   ok = gen_tcp:send(Data#data.socket, BinMsg),
   trace(Msg, out, Data).

trace(Msg, Direction, #data{session_id = SID, useTracer = true}) ->
   fix_tracer:trace(SID, Direction, Msg);
trace(_, _, _) -> ok.

print_use_tracer(SessionID, true) ->
   error_logger:info_msg("Session [~p] will use tracer.", [SessionID]);
print_use_tracer(_SessionID, _) ->
   ok.
