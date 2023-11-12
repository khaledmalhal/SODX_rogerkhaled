-module(muty_l3).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l3, Lock:start(3)),
    register(w3, worker:start("Paul", l3, Sleep, Work)),
    ok.

stop() ->
    w3 ! stop.
