% lock2.erl

-module(lock2).
-export([start/1, stop/0]).

start(MyId) ->
    spawn(fun() -> init(MyId) end).

init(Id) ->
    receive
        {peers, Nodes} ->
            open(Id, Nodes);
        stop ->
            ok
    end.

open(Id, Nodes) ->
    receive
        {take, Master, Ref, MasterId} ->
            Refs = requests(Nodes, Id, MasterId),
            wait(Nodes, Master, Refs, [], Ref);
        {request, From, Ref, RequesterId} ->
            From ! {ok, Ref, Id, RequesterId},
            open(Id, Nodes);
        stop ->
            ok
    end.

requests(Nodes, MyId, MyPriority) ->
    lists:map(
      fun(P) -> 
        R = make_ref(), 
        P ! {request, self(), R, MyPriority}, 
        R 
      end, 
      Nodes).

wait(Nodes, Master, [], Waiting, TakeRef) ->
    Master ! {taken, TakeRef},
    held(Nodes, Waiting);
wait(Nodes, Master, Refs, Waiting, TakeRef) ->
    receive
        {request, From, Ref, RequesterId} when RequesterId > MyId ->
            wait(Nodes, Master, Refs, [{From, Ref, RequesterId}|Waiting], TakeRef);
        {request, From, Ref, RequesterId} ->
            From ! {ok, Ref, Id, RequesterId},
            NewRefs = lists:delete(Ref, Refs),
            wait(Nodes, Master, NewRefs, Waiting, TakeRef);
        {ok, Ref, AcquirerId, _} when AcquirerId > MyId ->
            NewRefs = lists:delete(Ref, Refs),
            wait(Nodes, Master, NewRefs, Waiting, TakeRef);
        {ok, Ref, AcquirerId, RequesterId} ->
            wait(Nodes, Master, Refs, [{self(), Ref, RequesterId}|Waiting], TakeRef);
        release ->
            ok(Waiting),            
            open(Id, Nodes)
    end.

ok(Waiting) ->
    lists:map(
      fun({F,R,RequesterId}) -> 
        F ! {ok, R, RequesterId} 
      end, 
      Waiting).

held(Nodes, Waiting) ->
    receive
        {request, From, Ref, RequesterId} when RequesterId > MyId ->
            held(Nodes, [{From, Ref, RequesterId}|Waiting]);
        {request, From, Ref, RequesterId} ->
            held(Nodes, Waiting);
        release ->
            ok(Waiting),
            open(Id, Nodes)
    end.

