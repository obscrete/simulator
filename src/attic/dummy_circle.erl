-module(dummy_circle).
-export([get_area/0]).
-export([get_location_index/0, get_location_generator/1]).
-export([neighbour_distance_in_meters/0]).
-export([meters_to_degrees/1]).

-define(WIDTH, 20000).
-define(HEIGHT, 20000).

%% Exported: get_area

get_area() ->
    MinLongitude = -1.0 * ?WIDTH / 2,
    MaxLongitude = ?WIDTH / 2.0,
    MinLatitude = -1.0 * ?HEIGHT / 2,
    MaxLatitude = ?HEIGHT / 2.0,
    {MinLongitude, MaxLongitude, MinLatitude, MaxLatitude}.

%% Exported: read_index

get_location_index() ->
    Pi2 = math:pi() * 2,
    [{<<"Alice">>, 1, {Pi2 * 20, Pi2 / 16, 0, 2, 2500, {5000, 5000}, 0}},
     {<<"Bob">>,   2, {Pi2 * 20, Pi2 / 12, 0, 2, 2500, {-5000, 5000}, 0}},
     {<<"Carol">>, 3, {Pi2 * 20, Pi2 / 16, 0, 2, 2500, {-5000, -5000}, 0}},
     {<<"Dan">>,   4, {Pi2 * 20, Pi2 / 12, 0, 2, 2500, {5000, -5000}, 0}},
     {<<"Erin">>,  5, {Pi2 * 20, Pi2 / 16, 0, 2, 5000, {0, 0}, 0}}].

%% Exported: get_location_generator

get_location_generator({MaxAngle, DeltaAngle, Timestamp, TimeStep,
                        Radius, {OrigoLongitude, OrigoLatitude} = Origo,
                        Angle}) ->
    fun() ->
            if Angle > MaxAngle ->
                    end_of_locations;
               true ->
                    NextTimestamp =
                        Timestamp + TimeStep * (rand:uniform() / 2 + 0.5),
                    NextAngle = Angle + DeltaAngle * (rand:uniform() / 2 + 0.5),
                    Longitude = math:cos(NextAngle) * Radius + OrigoLongitude,
                    Latitude = math:sin(NextAngle) * Radius + OrigoLatitude,
                    {{NextTimestamp, Longitude, Latitude},
                     get_location_generator(
                       {MaxAngle, DeltaAngle, NextTimestamp, TimeStep, Radius,
                        Origo, NextAngle})}
            end
    end.

%% Exported: neighbour_distance_in_meters

neighbour_distance_in_meters() ->
    50.

%% Exported: meters_to_degrees

meters_to_degrees(_Meters) ->
    5000.0.
