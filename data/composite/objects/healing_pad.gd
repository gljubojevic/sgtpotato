extends Area2D

class_name HealingPad

# ============================================================================ #
#  States                                                                      #
# ============================================================================ #
class ActiveState extends State:
  func on_update(delta: float, state: HealingPad):
    var bodies = state.get_overlapping_bodies()
    if (state.regen_delay <= 0.0):
      state.current_energy = min(state.current_energy + delta * state.energy_regen, state.energy_max)
    var should_switch_state = false
    for body in bodies:
      if body.has_node('HealthAspect') && not body.get_node('HealthAspect').is_full():
        should_switch_state = true
        break
    if should_switch_state:
      state.current = transition_to(state.__discharging_state)

class DischargingState extends State:
  func on_update(delta: float, state: HealingPad):
    var bodies = state.get_overlapping_bodies()
    if bodies.size() == 0:
      state.current = transition_to(state.__active_state)
      return
    for body in bodies:
      if body.has_node('HealthAspect'):
        var health_aspect: HealthAspect = body.get_node('HealthAspect')
        if not health_aspect.is_full():
          state.regen_delay = state.delay_before_energy_regen
          health_aspect.heal(delta * state.healing_rate)
          state.current_energy = max(state.current_energy - delta * state.healing_rate, 0.0)
          if (state.current_energy <= 0.0):
            state.particles.emitting = false
            state.current = transition_to(state.__charging_state)

class ChargingState extends State:
  func on_update(delta: float, state: HealingPad):
    if (state.regen_delay <= 0):
      state.current_energy = min(state.current_energy + delta * state.energy_regen, state.energy_max)
    if state.current_energy >= state.reactivation_threshold * state.energy_max:
        state.particles.emitting = true
        state.current = transition_to(state.__active_state)

# preallocate states
var __active_state = ActiveState.new()
var __charging_state = ChargingState.new()
var __discharging_state = DischargingState.new()


# ============================================================================ #
#  Members                                                                     #
# ============================================================================ #
export (float) var energy_max = 100.0
export (float) var initial_energy = 1.0
export (float) var energy_regen = 10.0
export (float) var healing_rate = 10.0
export (float) var delay_before_energy_regen = 10.0
export (float) var reactivation_threshold = 0.5

export (bool) var debug = false

onready var particles = $Particles2D
onready var sprite = $Sprite
onready var debug_bars = $Debug

var current_energy = initial_energy * energy_max
var current = __active_state
var regen_delay = 0.0

# ============================================================================ #
#  Methods                                                                     #
# ============================================================================ #
func _ready():
  if not debug:
    remove_child(debug_bars)

func _process(delta: float) -> void:
  regen_delay = max(regen_delay - delta, 0.0)
  current.on_update(delta, self)
  sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0).darkened(0.5 * pow(1.0 - current_energy / energy_max, 2.0))
