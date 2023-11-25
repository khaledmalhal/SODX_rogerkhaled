-module(muty).
-export([start/3]).

% We use the name of the module (i.e. lock3) as a parameter to the start procedure. We also provide the average time (in milliseconds) the worker is going to sleep before trying to get the lock (Sleep) and work with the lock taken (Work).
start(Lock, Sleep, Work) ->
    ServerPid = spawn(fun() -> process_requests([], [], Lock, Sleep, Work) end),
    register(myserver, ServerPid).

process_requests(Workers, Locks, Lock, Sleep, Work) ->
    receive
        {worker_join_req, Name, From} ->
            io:format("Worker ~s is requesting to join~n", [Name]),
            % io:format("Registered names: ~p~n", [registered()]),
            Length = num(Locks),
            io:format("Length of list Locks: ~w~n", [Length]),
            LockPid = apply(Lock, start, [num(Locks) + 1]),
            io:format("LockPid's: ~p~n", [LockPid]),
            LockPid ! {peers, Locks},
            broadcast(Locks, {update, LockPid}),
            % if
            %     Length > 0.0 ->
            %         io:format("Updating Locks~n"),
            %         broadcast(Locks, {update, LockPid});
            %     true ->
            %         ok
            % end,
            From ! {create_worker, Name, LockPid, Sleep, Work},
            NewLocks = [LockPid|Locks],
            NewWorkers = [From|Workers],
            process_requests(NewWorkers, NewLocks, Lock, Sleep, Work);
        disconnect ->
            unregister(myserver),
            Workers ! stop
    end.

%% Local Functions
broadcast(PeerList, Message) ->
    Fun = fun(Peer) -> Peer ! Message end,
    lists:map(Fun, PeerList).

num(L) -> length([X || X <- L, X < 1]).
