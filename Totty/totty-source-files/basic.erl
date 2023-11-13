-module(basic).
-export([start/3]).

start(Id, Master, Jitter) ->
    spawn(fun() -> init(Id, Master, Jitter) end).

init(Id, Master, Jitter) ->
    {A1,A2,A3} = now(),
    random:seed(A1, A2, A3),
    receive
        {peers, Nodes} ->
            server(Id, Master, Nodes, Jitter)
    end.

server(Id, Master, Nodes, Jitter) ->
    receive
        {send, Msg} ->
            multicast(Msg, Nodes, Jitter),
            server(Id, Master, Nodes, Jitter);
        {multicast, _From, Msg} ->
            Master ! {deliver, Msg},
            server(Id, Master, Nodes, Jitter);
        stop ->
            ok
    end.

multicast(Msg, Nodes, 0) ->
    Self = self(),
    lists:foreach(fun(Node) -> 
                      Node ! {multicast, Self, Msg} 
                  end, 
                  Nodes);
multicast(Msg, Nodes, Jitter) ->
    Self = self(),
    lists:foreach(fun(Node) -> 
                      timer:sleep(random:uniform(Jitter)), 
                      Node ! {multicast, Self, Msg} 
                  end, 
                  Nodes).