-module(random_walk).
-export([get_location/0, get_location_index/0, get_location_generator/1,
         neighbour_distance/0, send_simulated_messages/1, center_target/0]).

-include_lib("apptools/include/shorthand.hrl").
-include_lib("apptools/include/log.hrl").
-include_lib("player/include/player_serv.hrl").
-include("simulator_location.hrl").

-define(LOCATION, stolofsgatan).
-define(DEFAULT_NUMBER_OF_PLAYERS, 100).
-define(INITIAL_DELAY, 5000).
-define(RESEND_TIME, (60000 * 4)).
-define(TARGET_NYM, <<"p1">>).

%%
%% Exported: get_location
%%

get_location() ->
    simulator_location:get(?LOCATION).

%%
%% Exported: get_location_index
%%

get_location_index() ->
    To = simulator:nplayer(?DEFAULT_NUMBER_OF_PLAYERS),
    get_location_index(1, To, simulator:scale_factor(), get_location()).

get_location_index(From, To, _ScaleFactor, _Location) when From > To ->
    [];
get_location_index(From, To,
                   ScaleFactor,
                   #simulator_location{
                      area = {MinLongitude, _MaxLongitude,
                              MinLatitude, _MaxLatitude},
                      width_in_degrees = WidthInDegrees,
                      height_in_degrees = HeightInDegrees} = Location) ->
    Label = ?l2b([<<"p">>, ?i2b(From)]),
    TimestampInSeconds = rand:uniform(),
    NextLongitudeDelta = fun() -> noise(0.05) end,
    NextLatitudeDelta = fun() -> noise(0.05) end,
    Longitude = MinLongitude + WidthInDegrees * rand:uniform(),
    Latitude = MinLatitude + HeightInDegrees * rand:uniform(),
    LongitudeDirection = random_direction(),
    LatitudeDirection = random_direction(),
    [{Label, From,
      {ScaleFactor,
       Location,
       0, TimestampInSeconds,
       MinLongitude, MinLatitude,
       NextLongitudeDelta, NextLatitudeDelta,
       Longitude, Latitude,
       LongitudeDirection, LatitudeDirection, 0}}|
     get_location_index(From + 1, To, ScaleFactor, Location)].

random_direction() ->
    case rand:uniform() > 0.5 of
        true ->
            1;
        false ->
            -1
    end.

%% https://en.wikipedia.org/wiki/Perlin_noise
noise(Step) ->
    A = rand:uniform(),
    B = rand:uniform(),
    {A, fun() -> noise(Step, Step, A, B) end}.

noise(1.0, Step, _A, B) ->
    {B, fun() -> noise(Step, Step, B, rand:uniform()) end};
noise(Travel, Step, _A, B) when Travel > 1 ->
    NextB = rand:uniform(),
    InterpolatedB = smoothstep(B, NextB, 1 - Travel),
    {InterpolatedB, fun() -> noise(Step - (1 - Travel), Step, B, NextB) end};
noise(Travel, Step, A, B) ->
    InterpolatedB = smoothstep(A, B, Travel),
    {InterpolatedB, fun() -> noise(Travel + Step, Step, A, B) end}.

%% https://en.wikipedia.org/wiki/Smoothstep
smoothstep(A, B, W) ->
    (B - A) * (3.0 - W * 2.0) * W * W + A.

%%
%% Exported: get_location_generator
%%

get_location_generator(
  {ScaleFactor,
   #simulator_location{width_in_degrees = WidthInDegrees,
                       height_in_degrees = HeightInDegrees,
                       meters_per_degree = MetersPerDegree,
                       update_frequency = UpdateFrequency,
                       degrees_per_update = DegreesPerUpdate} =
       Location,
   N, Timestamp,
   MinLongitude, MinLatitude,
   NextLongitudeDelta, NextLatitudeDelta,
   Longitude, Latitude,
   LongitudeDirection, LatitudeDirection, TotalDistance}) ->
    fun() ->
            UpdatedTimestamp = Timestamp + (1 / UpdateFrequency / ScaleFactor),
            {LongitudeDelta, EvenNextLongitudeDelta} = NextLongitudeDelta(),
            LongitudeMovement =
                DegreesPerUpdate * LongitudeDelta - DegreesPerUpdate / 2,
            {NewLongitude, NewLongitudeDirection} =
                maybe_change_direction(
                  MinLongitude, Longitude, LongitudeDirection,
                  LongitudeMovement, WidthInDegrees),
            {LatitudeDelta, EvenNextLatitudeDelta} = NextLatitudeDelta(),
            LatitudeMovement =
                DegreesPerUpdate * LatitudeDelta - DegreesPerUpdate / 2,
            {NewLatitude, NewLatitudeDirection} =
                maybe_change_direction(
                  MinLatitude, Latitude, LatitudeDirection, LatitudeMovement,
                  HeightInDegrees),
            UpdatedTotalDistance =
                TotalDistance +
                locationlib:distance(Longitude, Latitude, NewLongitude,
                                     NewLatitude) * MetersPerDegree,
%            io:format("m/s: ~w\n",
%                      [UpdatedTotalDistance /
%                           (UpdatedTimestamp * ScaleFactor)]),
            {{UpdatedTimestamp, NewLongitude, NewLatitude},
             get_location_generator(
               {ScaleFactor,
                Location,
                N + 1, UpdatedTimestamp,
                MinLongitude, MinLatitude,
                EvenNextLongitudeDelta, EvenNextLatitudeDelta,
                NewLongitude, NewLatitude,
                NewLongitudeDirection, NewLatitudeDirection,
                UpdatedTotalDistance})}
    end.

maybe_change_direction(MinCoordinate, Coordinate, Direction, Movement, Side) ->
    case Coordinate + Direction * Movement of
        NewCoordinate when NewCoordinate > MinCoordinate andalso
                           NewCoordinate < MinCoordinate + Side ->
            {NewCoordinate, Direction};
        _ ->
            NewDirection = -Direction,
            {Coordinate + NewDirection * Movement, NewDirection}
    end.

%%
%% Exported: neighbour_distance
%%

neighbour_distance() ->
    Location = get_location(),
    Location#simulator_location.neighbour_distance_in_degrees.

%%
%% Exported: send_simulated_messages
%%

send_simulated_messages(Players) ->
    ScaleFactor = simulator:scale_factor(),
    timer:apply_after(trunc(?INITIAL_DELAY / ScaleFactor),
                      simulator, send_messages,
                      [Players, ScaleFactor, ?TARGET_NYM, ?RESEND_TIME]).

%%
%% Exported: center_target
%%

center_target() ->
    {true, ?TARGET_NYM}.
