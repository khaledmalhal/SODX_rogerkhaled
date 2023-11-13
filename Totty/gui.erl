-module(gui).
-export([start/1]).
-define(width, 200).
-define(height, 200).
-include_lib("wx/include/wx.hrl").

start(Name) ->
    spawn_link(fun() -> init(Name) end).

init(Name) ->
    Frame = make_frame(Name),
    loop(Frame).

make_frame(Name) ->       %Name is the window title
    Server = wx:new(),  %Server will be the parent for the Frame
    Frame = wxFrame:new(Server, -1, Name, [{size,{?width, ?height}}]),
    wxFrame:setBackgroundColour(Frame, ?wxBLACK),
    wxFrame:show(Frame),
    %monitor closing window event
    wxFrame:connect(Frame, close_window),
    Frame.

loop(Frame)->
    receive
        %check if the window was closed by the user
        #wx{event=#wxClose{}} ->
            wxWindow:destroy(Frame),  
            ok;
        {color, Color} ->
            color(Frame, Color),
            loop(Frame);
        stop ->
            ok;
        Error ->
            io:format("gui: strange message ~w ~n", [Error]),
            loop(Frame)
    end.

color(Frame, Color) ->
    wxFrame:setBackgroundColour(Frame, Color),
    wxFrame:refresh(Frame).