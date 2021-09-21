#include "script_component.hpp"
/* ----------------------------------------------------------------------------
Internal Function: cba_optics_fnc_animateScriptedOptic

Description:
    Executed every draw frame to update the scripted weapon info display.

Parameters:
    _display - CBA weapon info display <DISPLAY>

Returns:
    Nothing.

Examples:
    (begin example)
        _weaponInfoDisplay call cba_optics_fnc_animateScriptedOptic;
    (end)

Author:
    commy2
---------------------------------------------------------------------------- */

params ["_display"];
if (!ctrlShown (_display displayCtrl IDC_ACTIVE_DISPLAY)) exitWith {};
uiNamespace setVariable [QGVAR(ScriptedOpticDisplay), _display];

private _ctrlRedDot = _display displayCtrl IDC_RED_DOT;
private _ctrlReticle = _display displayCtrl IDC_RETICLE;
private _ctrlBody = _display displayCtrl IDC_BODY;
private _ctrlBodyNight = _display displayCtrl IDC_BODY_NIGHT;
private _ctrlBodyInnerShadow = _display displayCtrl IDC_BODY_INNER_SHADOW;
private _ctrlBlackScope = _display displayCtrl IDC_BLACK_SCOPE;
private _ctrlBlackLeft = _display displayCtrl IDC_BLACK_LEFT;
private _ctrlBlackRight = _display displayCtrl IDC_BLACK_RIGHT;
private _ctrlReticleSafezone = _display displayCtrl IDC_RETICLE_SAFEZONE;
private _ctrlZeroing = _display displayCtrl 168;
private _ctrlMagnification = _display displayCtrl IDC_MAGNIFICATION;

// Check if optics are used, hide all controls otherwise.
private _isUsingOptic = ctrlShown (_display displayCtrl 154);

_ctrlRedDot ctrlShow _isUsingOptic;
_ctrlReticle ctrlShow _isUsingOptic;
_ctrlBody ctrlShow _isUsingOptic;
_ctrlBodyNight ctrlShow _isUsingOptic;
_ctrlBodyInnerShadow ctrlShow _isUsingOptic;
_ctrlBlackScope ctrlShow _isUsingOptic;
_ctrlBlackLeft ctrlShow _isUsingOptic;
_ctrlBlackRight ctrlShow _isUsingOptic;
//_ctrlZeroing ctrlShow _isUsingOptic;
_ctrlMagnification ctrlShow _isUsingOptic;

GVAR(ppEffects) ppEffectEnable _isUsingOptic;

if (_isUsingOptic isNotEqualTo GVAR(IsUsingOptic)) then {
    GVAR(IsUsingOptic) = _isUsingOptic;
    [QGVAR(UsingOptic), [_display, _isUsingOptic]] call CBA_fnc_localEvent;
};

if !(_isUsingOptic) exitWith {};

GVAR(camera) setPosASL AGLToASL positionCameraToWorld [0,0,0.4];
GVAR(camera) camPrepareTarget positionCameraToWorld [0,0,50];
GVAR(camera) camCommitPrepared 0;

// @todo, check if that needs to be done at all
if (cameraView == "GUNNER") then {
    GVAR(camera) camSetFOV 0.75;
    GVAR(camera) camCommit 0;
} else {
    GVAR(camera) camSetFOV 0.01;
    GVAR(camera) camCommit 0;
};

// Add magnification to zeroing control.
private _zoom = 0.25 call CBA_fnc_getFov select 1;

_ctrlMagnification ctrlSetText format [
    "(%1x)",
    [_zoom, 1, 1] call CBA_fnc_formatNumber
];

_ctrlMagnification ctrlShow (_zoom >= 1 && {!GVAR(hideMagnification)});

private _positionMagnification = ctrlPosition _ctrlZeroing;
_positionMagnification set [0, _positionMagnification#0 + ctrlTextWidth _ctrlZeroing];

_ctrlMagnification ctrlSetPosition _positionMagnification;
_ctrlMagnification ctrlCommit 0;

// Calculate lighting.
private _dayOpacity = AMBIENT_BRIGHTNESS;
private _nightOpacity = [1,0] select (_dayOpacity == 1);

private _useReticleNight = GVAR(useReticleNight);

if (!GVAR(manualReticleNightSwitch)) then {
    _useReticleNight = _dayOpacity < 0.5;
};

// Apply lighting and make layers visible.
private _texture = "";
private _detailScaleFactor = 1;

{
    _x params ["_zoomX", "_textureX", "_detailScaleFactorX", "_textureXNight"];

    if (_zoom > _zoomX) then {
        _texture = [_textureX, _textureXNight] select _useReticleNight;
        _detailScaleFactor = _detailScaleFactorX;
    };
} forEach GVAR(OpticReticleDetailTextures);

_display setVariable [QGVAR(DetailScaleFactor), _detailScaleFactor];

_ctrlReticle ctrlSetText _texture;
_ctrlBody ctrlSetTextColor [1,1,1,_dayOpacity];
_ctrlBodyNight ctrlSetTextColor [1,1,1,_nightOpacity];
_ctrlBlackScope ctrlShow (GVAR(usePipOptics) && !isPipEnabled);

// tilt while leaning
private _bank = 0;

if (!GVAR(disableTilt)) then {
    _bank = call FUNC(gunBank);
};

_ctrlReticle ctrlSetAngle [_bank, 0.5, 0.5];
_ctrlBody ctrlSetAngle [_bank, 0.5, 0.5];
_ctrlBodyNight ctrlSetAngle [_bank, 0.5, 0.5];
_ctrlBodyInnerShadow ctrlSetAngle [_bank, 0.5, 0.5];



// TODO:
// 1) Fix PP effect remains on exiting gunner view when blurry
// 2) Implement reticle movement (or disable it) for multilevel zoom optics
// 3) Recoil effects?
// On move anim
private _camDir = getDir GVAR(camera);

private _camPitch = (GVAR(camera) call BIS_fnc_getPitchBank) # 0;
private _sizeBody = 0.99 * GVAR(OpticBodyTextureSize);
private _sizeReticle = _display getVariable [QGVAR(DetailScaleFactor), 1];

diag_log ["Dir: %1, Pitch: %2", _camDir, _camPitch];

#define VELOCITY_INNER_SHADOW_MIN 0.06
#define VELOCITY_INNER_SHADOW_MAX 1.5
#define VELOCITY_UNFOCUS_MIN 0.9
#define VELOCITY_UNFOCUS_MAX 1.5
#define VELOCITY_RETICLE_MIN VELOCITY_INNER_SHADOW_MIN/2
#define VELOCITY_RETICLE_MAX VELOCITY_INNER_SHADOW_MAX/2

#define ANIM_SCALE_MAX 0.9
#define ANIM_OFFSET_INNER_SHADOW 0.1
#define ANIM_UNFOCUS_POWER 3
#define ANIM_OFFSET_RETICLE ANIM_OFFSET_INNER_SHADOW/2

#define ANIM_FRAMES(X) diag_frameNo + diag_fps * X
#define ANIM_APPLY_TIME 0.1
#define ANIM_RESET_TIME 0.3


if (diag_frameNo > GVAR(onMoveAnimEndFrame) && GVAR(onMoveAnimStarted)) then {
    systemChat "Reset shadow...";
    diag_log "## Resetting inner shadow anim";

    GVAR(onMoveAnimStarted) = false;

    // Reset shadow animation
    _ctrlBodyInnerShadow ctrlSetPosition [
        POS_X(_sizeBody),
        POS_Y(_sizeBody),
        POS_W(_sizeBody),
        POS_H(_sizeBody)
    ];
    _ctrlBodyInnerShadow ctrlCommit ANIM_RESET_TIME;

    // Reset reticle
    _ctrlReticle ctrlSetPosition [
        POS_X(_sizeReticle),
        POS_Y(_sizeReticle),
        POS_W(_sizeReticle),
        POS_H(_sizeReticle)
    ];
    _ctrlReticle ctrlCommit ANIM_RESET_TIME;

    // Reset blur/unfocus
    GVAR(onMovePPEffect) ppEffectAdjust [0];
    GVAR(onMovePPEffect) ppEffectCommit ANIM_RESET_TIME;
} else {
    private _dirDelta = GVAR(camDirPrevFrame) - _camDir;
    private _pitchDelta = GVAR(camPitchPrevFrame) - _camPitch;
    private _angularVel = abs(_dirDelta) max abs(_pitchDelta);
    diag_log format ["Delta: %1", _dirDelta];

    // On camera move...
    if (diag_frameNo > GVAR(onMoveAnimSafeFrame) && _angularVel >= VELOCITY_INNER_SHADOW_MIN) then {
        diag_log "## Adjusting anim";
        systemChat "Adjusting...";

        GVAR(onMoveAnimStarted) = true;
        GVAR(onMoveAnimEndFrame) = ANIM_FRAMES(ANIM_APPLY_TIME);
        GVAR(onMoveAnimSafeFrame) = ANIM_FRAMES(ANIM_APPLY_TIME / 2);

        // Animate inner shadow parallax
        private _offsetShadowX = linearConversion [
            -VELOCITY_INNER_SHADOW_MAX, VELOCITY_INNER_SHADOW_MAX, _dirDelta,
            -ANIM_OFFSET_INNER_SHADOW, ANIM_OFFSET_INNER_SHADOW, true
        ];
        private _offsetShadowY = linearConversion [
            -VELOCITY_INNER_SHADOW_MAX, VELOCITY_INNER_SHADOW_MAX, _pitchDelta,
            -ANIM_OFFSET_INNER_SHADOW, ANIM_OFFSET_INNER_SHADOW, true
        ];
        private _scaleShadow = linearConversion [
            0, VELOCITY_INNER_SHADOW_MAX, _angularVel, 1, ANIM_SCALE_MAX, true
        ];
        diag_log format [
            "## Offset: [%1, %2, %3], Dir Delta: %4, Pitch delta: %5",
            _offsetShadowX, _offsetShadowY, _scaleShadow, _dirDelta, _pitchDelta
        ];

        private _positionBodyInnerShadow = [
            POS_X(_sizeBody * _scaleShadow + _offsetShadowX),
            POS_Y(_sizeBody * _scaleShadow + _offsetShadowY),
            POS_W(_sizeBody * _scaleShadow),
            POS_H(_sizeBody * _scaleShadow)
        ];

        _ctrlBodyInnerShadow ctrlSetPosition _positionBodyInnerShadow;
        _ctrlBodyInnerShadow ctrlSetTextColor [1,1,1,1];
        _ctrlBodyInnerShadow ctrlCommit ANIM_APPLY_TIME;

        // Optional effects:
        // - Animate reticle
        if (_angularVel >= VELOCITY_RETICLE_MIN) then {
            diag_log "## Apply reticle animation";
            private _offsetReticleX = linearConversion [
                -VELOCITY_RETICLE_MAX, VELOCITY_RETICLE_MAX, _dirDelta,
                -ANIM_OFFSET_RETICLE, ANIM_OFFSET_RETICLE, true
            ];
            private _offsetReticleY = linearConversion [
                -VELOCITY_RETICLE_MAX, VELOCITY_RETICLE_MAX, _pitchDelta,
                -ANIM_OFFSET_RETICLE, ANIM_OFFSET_RETICLE, true
            ];

            private _positionReticle = [
                POS_X(_sizeReticle + _offsetReticleX),
                POS_Y(_sizeReticle + _offsetReticleY),
                POS_W(_sizeReticle),
                POS_H(_sizeReticle)
            ];

            _ctrlReticle ctrlSetPosition _positionReticle;
            _ctrlReticle ctrlCommit ANIM_APPLY_TIME;
        };

        // - Apply blur to simulate focus losing
        if (_angularVel >= VELOCITY_UNFOCUS_MIN) then {
            diag_log "## Apply unfocus animation";
            private _ppEffect = GVAR(onMovePPEffect);
            private _unfocusPower = linearConversion [
                0, VELOCITY_UNFOCUS_MAX, _angularVel,
                0, ANIM_UNFOCUS_POWER, true
            ];

            diag_log format ["## Unfocus power: %1", _unfocusPower];
            _ppEffect ppEffectEnable true;
            _ppEffect ppEffectAdjust [_unfocusPower];
            _ppEffect ppEffectCommit ANIM_APPLY_TIME;
        };
    } else {
        systemChat "Anim safe time in progress";
    };
};

// Restore state if on move animation reset completed
// if (ctrlPosition _ctrlBodyInnerShadow # 2 > POS_W(_sizeBody * 0.98)) then {
if (ctrlCommitted _ctrlBodyInnerShadow) then {
    // _ctrlBodyInnerShadow ctrlSetTextColor [1,1,1,0];
    GVAR(onMovePPEffect) ppEffectEnable false;
};

GVAR(camDirPrevFrame) = _camDir;
GVAR(camPitchPrevFrame) = _camPitch;


// zooming reticle
if (isNull (_display displayCtrl IDC_ENABLE_ZOOM)) exitWith {};

if (_zoom >= 1) then {
    GVAR(magnificationCache) = _zoom;
};

GVAR(ReticleAdjust) set [2, _zoom];
private _reticleAdjust = linearConversion GVAR(ReticleAdjust);
private _sizeReticle = _reticleAdjust * _detailScaleFactor;
ctrlPosition _ctrlReticleSafezone params ["_reticleSafeZonePositionLeft", "_reticleSafeZonePositionTop"];

private _positionReticle = [
    POS_X(_sizeReticle) - _reticleSafeZonePositionLeft,
    POS_Y(_sizeReticle) - _reticleSafeZonePositionTop,
    POS_W(_sizeReticle),
    POS_H(_sizeReticle)
];

// Apply changes only after animation end? ???
if (!GVAR(onMoveAnimStarted)) then {
    _ctrlReticle ctrlSetPosition _positionReticle;

    if (ctrlCommitted _ctrlBody) then {
        _ctrlReticle ctrlCommit 0;
    };
};

if (_zoom > GVAR(HideRedDotMagnification)) then {
    _ctrlRedDot ctrlShow false;
};

GVAR(FadeReticleInterval) set [2, _zoom];
_ctrlReticle ctrlSetTextColor [1,1,1,linearConversion GVAR(FadeReticleInterval)];
