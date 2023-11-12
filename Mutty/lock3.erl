-module(lock3).
-export([start/1, stop/0]).

start(MyId) ->
    spawn(fun() -> init(MyId) end).

init(Id) ->
    receive
        {peers, Nodes} ->
            open(Id, Nodes, 0);
        stop ->
            ok
    end.

open(Id, Nodes, Clock) ->
    receive
        {take, Master, Ref, MasterId, MasterClock} ->
            Refs = requests(Nodes, Id, MasterId, Clock),
            wait(Nodes, Master, Refs, [], Ref, MasterClock, Clock);
        {request, From, Ref, RequesterId, RequesterClock} ->
            From ! {ok, Ref, Id, RequesterId, RequesterClock},
            open(Id, Nodes, Clock);
        stop ->
            ok
    end.

requests(Nodes, MyId, MyPriority, Clock) ->
    lists:map(
      fun(P) -> 
        R = make_ref(), 
        P ! {request, self(), R, MyPriority, Clock}, 
        R 
      end, 
      Nodes).

wait(Nodes, Master, [], Waiting, TakeRef, MasterClock, Clock) ->
    Master ! {taken, TakeRef},
    held(Nodes, Waiting, MasterClock, Clock);
wait(Nodes, Master, Refs, Waiting, TakeRef, MasterClock, Clock) ->
    receive
        {request, From, Ref, RequesterId, RequesterClock} when RequesterClock > Clock ->
            wait(Nodes, Master, Refs, [{From, Ref, RequesterId, RequesterClock}|Waiting], TakeRef, MasterClock, Clock);
        {request, From, Ref, RequesterId, RequesterClock} when RequesterClock < Clock ->
            From ! {ok, Ref, Id, RequesterId, RequesterClock},
            NewRefs = lists:delete(Ref, Refs),
            wait(Nodes, Master, NewRefs, Waiting, TakeRef, MasterClock, Clock);
        {request, From, Ref, RequesterId, RequesterClock} when RequesterClock == Clock, RequesterId > Id ->
            wait(Nodes, Master, Refs, [{From, Ref, RequesterId, RequesterClock}|Waiting], TakeRef, MasterClock, Clock);
        {request, From, Ref, RequesterId, RequesterClock} when RequesterClock == Clock, RequesterId < Id ->
            From ! {ok, Ref, Id, RequesterId, RequesterClock},
            NewRefs = lists:delete(Ref, Refs),
            wait(Nodes, Master, NewRefs, Waiting, TakeRef, MasterClock, Clock);
        {ok, Ref, AcquirerId, _, _} when AcquirerId > Id ->
            NewRefs = lists:delete(Ref, Refs),
            wait(Nodes, Master, NewRefs, Waiting, TakeRef, MasterClock, Clock);
        {ok, Ref, AcquirerId, _, _} when AcquirerId < Id ->
            wait(Nodes, Master, Refs, [{self(), Ref, AcquirerId, MasterClock, Clock}|Waiting], TakeRef, MasterClock, Clock);
        release ->
            ok(Waiting),            
            open(Id, Nodes, Clock)
    end.

ok(Waiting) ->
    lists:map(
      fun({F,R,AcquirerId,MasterClock,Clock}) -> 
        F ! {ok, R, AcquirerId, MasterClock, Clock} 
      end, 
      Waiting).

held(Nodes, Waiting, MasterClock, Clock) ->
    receive
        {request, From, Ref, RequesterId, RequesterClock} when RequesterClock > Clock ->
            held(Nodes, [{From, Ref, RequesterId, RequesterClock}|Waiting], MasterClock, Clock);
        {request, From, Ref, RequesterId, RequesterClock} when RequesterClock < Clock ->
            held(Nodes, Waiting, MasterClock, Clock);
        {request, From, Ref, RequesterId, RequesterClock} when RequesterClock == Clock, RequesterId > Id ->
            held(Nodes, [{From, Ref, RequesterId, RequesterClock}|Waiting], MasterClock, Clock);
        {request, From, Ref, RequesterId, RequesterClock} when RequesterClock == Clock, RequesterId < Id ->
            held(Nodes, Waiting, MasterClock, Clock);
        {release, AcquirerId, AcquirerClock} when AcquirerClock > Clock ->
            held(Nodes, Waiting, MasterClock, AcquirerClock);
        {release, AcquirerId, AcquirerClock} when AcquirerClock < Clock ->
            ok(Waiting),
            open(Id, Nodes, Clock);
        release ->
            ok(Waiting),
            open(Id, Nodes, Clock)
    end.

