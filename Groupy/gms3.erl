-module(gms3).
-export([start/1, start/2]).
-define(timeout, 1000).
-define(arghh, 10000000).

start(Name) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Self) end).

init(Name, Master) ->
    {A1,A2,A3} = erlang:timestamp(),
    random:seed(A1, A2, A3),
    leader(Name, Master, [], 0).

start(Name, Grp) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Grp, Self) end).

init(Name, Grp, Master) ->
    {A1,A2,A3} = erlang:timestamp(),
    random:seed(A1, A2, A3),
    Self = self(),
    Grp ! {join, Self},
    receive
        {view, Leader, Slaves, Seq} ->
            io:format("[~s] Init. Monitoring the Leader: ~w~n", [Name, Leader]),
            MonitorRef = erlang:monitor(process, Leader),
            Master ! joined,
            slave(Name, Master, Leader, Slaves, MonitorRef, Seq, {view, Leader, Slaves, Seq})
    after ?timeout ->
        Master ! {error, "no reply from leader"}
    end.

election(Name, Master, Slaves, MonitorRef, N, Last) ->
    Self = self(),
    case Slaves of
        [Self|Rest] ->
            io:format("[~s] I am the new Leader. Pid: ~w~n", [Name, Self]),
            bcast(Name, {view, Self, Rest, N}, Rest),
            leader(Name, Master, Rest, N);
        [NewLeader|Rest] ->
            io:format("[~s] ~w is the new Leader~n", [Name, NewLeader]),
            slave(Name, Master, NewLeader, Rest, MonitorRef, N, Last)
    end.

leader(Name, Master, Slaves, N) ->
    io:format("Leader ~s. N: ~w~n", [Name, N]),
    receive
        {mcast, Msg} ->
            bcast(Name, {msg, Msg, N}, Slaves),
            Master ! {deliver, Msg},
            leader(Name, Master, Slaves, N + 1);
        {join, Peer} ->
            NewSlaves = lists:append(Slaves, [Peer]),
            io:format("Leader (~s): Peer wants to join (~w) ~n", [Name, Peer]),
            bcast(Name, {view, self(), NewSlaves, N}, NewSlaves),
            leader(Name, Master, NewSlaves, N + 1);
        stop ->
            ok;
        Error ->
            io:format("leader ~s: strange message ~w~n", [Name, Error])
    end.

bcast(Name, Msg, Nodes) ->
    lists:foreach(fun(Node) -> Node ! Msg, crash(Name, Msg) end, Nodes).

crash(Name, Msg) ->
    case random:uniform(?arghh) of
        ?arghh ->
            io:format("leader ~s CRASHED: msg ~w~n", [Name, Msg]),
            exit(no_luck);
        _ ->
            ok
    end.

slave(Name, Master, Leader, Slaves, MonitorRef, N, Last) ->
    io:format("Slave ~s. N: ~w~n", [Name, N]),
    receive
        {mcast, Msg} ->
            %Ignora mensajes con numero de secuencia repetidos
            Leader ! {mcast, Msg},
            slave(Name, Master, Leader, Slaves, MonitorRef, N, Last);
        {join, Peer} ->
            Leader ! {join, Peer},
            io:format("Slave (~s): Peer (~w) wants to join ~n", [Name, Peer]),
            slave(Name, Master, Leader, Slaves, MonitorRef, N, Last);
        {msg, Msg, Seq} when Seq > N ->
            io:format("~nSlave ~s. Received msg with Seq ~w.~n", [Name, Seq]),
            %Ignora mensajes con numero de secuencia repetidos
            Master ! {deliver, Msg},
            slave(Name, Master, Leader, Slaves, MonitorRef, Seq, {msg, Msg, Seq});
        {view, NewLeader, NewSlaves, Seq} when Seq > N ->
            io:format("~nSlave ~s. Received view with Seq ~w.~n", [Name, Seq]),
            erlang:demonitor(MonitorRef, [flush]),
            NewRef = erlang:monitor(process, NewLeader),
            io:format("[~s] Remonitoring the New Leader (~w)~n", [Name, NewLeader]),
            slave(Name, Master, NewLeader, NewSlaves, NewRef, Seq, {view, NewLeader, NewSlaves, Seq});
        {'DOWN', _Ref, process, Leader, _Reason} ->
            io:format("[~s] Our Leader, ~w, is down. Making a new election~n", [Name, Leader]),
            election(Name, Master, Slaves, MonitorRef, N, Last);
        stop ->
            ok;
        Error ->
            io:format("slave ~s: strange message ~w~n", [Name, Error])
    end.

