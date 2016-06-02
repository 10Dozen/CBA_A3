/* ----------------------------------------------------------------------------
Function: CBA_fnc_moduleAttack

Description:
    A function for commanding a group to patrol a location with information
    parsed from a module.

Parameters:
    Logic Parameters (Must be passed associated with Object using "setVariable")
    - Location Type (String)
        setVariable ["patrolLocType", value]
    - Patrol Radius (Scalar)
        setVariable ["patrolRadius", value]
    - Waypoint Count (Scalar)
        setVariable ["waypointCount", value]
    - Waypoint Type (String)
        setVariable ["waypointType", value]
    - Behaviour (String)
        setVariable ["behaviour", value]
    - Combast Mode (String)
        setVariable ["combatMode", value]
    - Speed Mode (String)
        setVariable ["speedMode", value]
    - Formation (String)
        setVariable ["formation", value]
    - Timeout at each waypoint (Array in String "[Min,Med,Max]")
        setVariable ["timeout", value]
    
    Group Parameter
    - Group Leader(s) (Array)

Optional:
    - Patrol Center (XYZ, Object, Location, Marker, or Task)
        setVariable ["patrolPosition", value]
    - Code to Execute at Each Waypoint (String)
        setVariable ["executableCode", value]

Example:
    (begin example)
    [Logic, [group1,group2,...,groupN]] call CBA_fnc_modulePatrol;
    (end)

Returns:
    Nil

Author:
    WiredTiger

---------------------------------------------------------------------------- */

#include "script_component.hpp"

params [
    ["_logic",objNull,[objNull]],
    ["_groups",[],[[]]],
    "_localGroups",
    "_patrolPos",
    "_patrolRadius",
    "_waypointCount",
    "_waypointType",
    "_behaviour",
    "_combatMode",
    "_speedMode",
    "_formation",
    "_codeToRun",
    "_timeout"
];

// Only server, dedicated, or headless beyond this point
if (hasInterface && !isServer) exitWith {};

_localGroups = [];

{
    // Find owner of unit if headless client is present
    if (local _x) then {
        _localGroups pushBack _x;
    };
} forEach _groups;

if (_localGroups isEqualTo []) exitWith {};

// Define variables
_patrolLocType = _logic getVariable "patrolLocType";
_patrolPos = _logic getVariable "patrolPosition";
_patrolSetPos = false;

// Parse patrol position from string
_patrolPos = [_patrolLocType, _patrolPos] call CBA_fnc_getStringPos;
if (isNil "_patrolPos") then {_patrolSetPos = true;};

// Parse timeout using getStringPos
_timeout = _logic getVariable "timeout";
_timeout = ["ARRAY",_timeout] call CBA_fnc_getStringPos;

// Define remaining variables and command local group leaders to patrol area
_patrolRadius = _logic getVariable "patrolRadius";
_waypointCount = _logic getVariable "waypointCount";
_waypointType = _logic getVariable "waypointType";
_behaviour = _logic getVariable "behaviour";
_combatMode = _logic getVariable "combatMode";
_speedMode = _logic getVariable "speedMode";
_formation = _logic getVariable "formation";
_codeToRun = _logic getVariable "executableCode";
{
    if (_patrolSetPos) then {_patrolPos = getPos _x;};
    [
        _x,
        _patrolPos,
        _patrolRadius,
        _waypointCount,
        _waypointType,
        _behaviour,
        _combatMode,
        _speedMode,
        _formation,
        _codeToRun,
        _timeout
    ] call CBA_fnc_taskPatrol;
} forEach _localGroups;
