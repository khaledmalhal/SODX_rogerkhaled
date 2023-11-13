-module(muty).
-export([start/3]).

% We use the name of the module (i.e. lock3) as a parameter to the start procedure. We also provide the average time (in milliseconds) the worker is going to sleep before trying to get the lock (Sleep) and work with the lock taken (Work).
start(Lock, Sleep, Work) ->
    ServerPid = spawn(fun() -> process_requests([], Lock, Sleep, Work) end),
    register(myserver, ServerPid).

process_requests(Workers, Lock, Sleep, Work) ->
    receive
        {worker_join_req, Name, From} ->
            io:format("Worker ~s is requesting to join~n", [Name]),
            % io:format("Registered names: ~p~n", [registered()]),
            Locks = lists:delete(myserver, registered()),
            Length = num(Locks),
            io:format("Length of list Locks: ~w~n", [Length]),
            register(lock, apply(Lock, start, [num(Locks) + 1])),
            lock ! {peers, Locks},
            if
                Length > 0.0 ->
                    broadcast(Locks, {update, lock});
                true ->
                    ok
            end,
            From ! {create_worker, Name, whereis(lock), Sleep, Work},
            NewWorkers = [From|Workers],
            process_requests(NewWorkers, Lock, Sleep, Work);
        disconnect ->
            unregister(myserver),
            Workers ! stop
    end.

%% Local Functions
broadcast(PeerList, Message) ->
    Fun = fun(Peer) -> Peer ! Message end,
    lists:map(Fun, PeerList).

num(L) -> length([X || X <- L, X < 1]).
