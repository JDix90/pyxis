class_name Smoothing
extends Object
# Frame-rate-independent exponential smoothing.
#
# The pattern this replaces is `value = lerp(value, target, rate * delta)`, which
# is everywhere in this codebase and is wrong in two ways that only show up off
# 60Hz. It is not frame-rate independent -- one step at 1/60 lands somewhere
# different from two steps at 1/120, so the camera feels different on a 120Hz
# phone than it does on the machine it was tuned on. And `rate * delta` above 1.0
# overshoots the target and oscillates, which is what a long frame produces:
# ZOOM_LERP of 9.0 passes 1.0 at 9 FPS and inverts from there.
#
# The correct form is the analytic solution to the same differential equation:
#
#     value = target + (value - target) * exp(-rate * delta)
#
# exp(-r*(a+b)) == exp(-r*a) * exp(-r*b), so any subdivision of a timestep gives
# the same answer, and the factor is in (0, 1] for every non-negative delta, so
# it can approach the target but never cross it.
#
# `rate` keeps the meaning it had in the old calls -- larger is faster, and at
# 60Hz the two agree closely enough that existing tuning carries over. It is
# nominally "1/e of the remaining distance per second".

# Below this the exponential is indistinguishable from the target and we are
# just burning float precision on a value that will never visibly move again.
const SNAP_EPSILON := 0.00001


static func factor(rate: float, delta: float) -> float:
	# The shared term. Exposed so callers smoothing several fields at one rate
	# can pay for the exp() once.
	return exp(-maxf(rate, 0.0) * maxf(delta, 0.0))


static func toward(current: float, target: float, rate: float, delta: float) -> float:
	var f := factor(rate, delta)
	var out := target + (current - target) * f
	return target if absf(out - target) < SNAP_EPSILON else out


static func toward_vec3(current: Vector3, target: Vector3, rate: float, delta: float) -> Vector3:
	var f := factor(rate, delta)
	var out := target + (current - target) * f
	return target if out.distance_squared_to(target) < SNAP_EPSILON * SNAP_EPSILON else out


static func toward_vec2(current: Vector2, target: Vector2, rate: float, delta: float) -> Vector2:
	var f := factor(rate, delta)
	var out := target + (current - target) * f
	return target if out.distance_squared_to(target) < SNAP_EPSILON * SNAP_EPSILON else out


static func toward_color(current: Color, target: Color, rate: float, delta: float) -> Color:
	var f := factor(rate, delta)
	return Color(
		target.r + (current.r - target.r) * f,
		target.g + (current.g - target.g) * f,
		target.b + (current.b - target.b) * f,
		target.a + (current.a - target.a) * f,
	)


static func decay(current: float, rate: float, delta: float) -> float:
	# toward(current, 0.0, ...). Named separately because "this returns to rest"
	# reads differently from "this chases a target" at the call site.
	return toward(current, 0.0, rate, delta)


static func toward_asymmetric(current: float, target: float, rise: float, fall: float, delta: float) -> float:
	# Two rates, picked by direction of travel. Bars that show damage use this:
	# a hull readout that eases downward as gently as it eases upward reads as
	# input lag on the frame you get hit, which is the one frame that must not.
	return toward(current, target, rise if target > current else fall, delta)
