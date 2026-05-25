extends Node3D

var webxr_interface
var _move_shape: SphereShape3D
var _move_query: PhysicsShapeQueryParameters3D

var _teleport_target: Vector3 = Vector3.ZERO
var _has_teleport_target: bool = false

func _ready() -> void:
  _move_shape = SphereShape3D.new()
  _move_shape.radius = 0.3
  _move_query = PhysicsShapeQueryParameters3D.new()
  _move_query.shape = _move_shape

  $CanvasLayer.visible = false
  $CanvasLayer/Button.pressed.connect(self._on_button_pressed)

  webxr_interface = XRServer.find_interface("WebXR")
  if webxr_interface:
    # WebXR uses a lot of asynchronous callbacks, so we connect to various
    # signals in order to receive them.
    webxr_interface.session_supported.connect(self._webxr_session_supported)
    webxr_interface.session_started.connect(self._webxr_session_started)
    webxr_interface.session_ended.connect(self._webxr_session_ended)
    webxr_interface.session_failed.connect(self._webxr_session_failed)

    webxr_interface.select.connect(self._webxr_on_select)
    webxr_interface.selectstart.connect(self._webxr_on_select_start)
    webxr_interface.selectend.connect(self._webxr_on_select_end)

    webxr_interface.squeeze.connect(self._webxr_on_squeeze)
    webxr_interface.squeezestart.connect(self._webxr_on_squeeze_start)
    webxr_interface.squeezeend.connect(self._webxr_on_squeeze_end)

    # This returns immediately - our _webxr_session_supported() method
    # (which we connected to the "session_supported" signal above) will
    # be called sometime later to let us know if it's supported or not.
    webxr_interface.is_session_supported("immersive-vr")

  $XROrigin3D/LeftController.button_pressed.connect(self._on_left_controller_button_pressed)
  $XROrigin3D/LeftController.button_released.connect(self._on_left_controller_button_released)

func _webxr_session_supported(session_mode: String, supported: bool) -> void:
  if session_mode == 'immersive-vr':
    if supported:
      $CanvasLayer.visible = true
    else:
      OS.alert("Your browser doesn't support VR")

func _on_button_pressed() -> void:
  # We want an immersive VR session, as opposed to AR ('immersive-ar') or a
  # simple 3DoF viewer ('viewer').
  webxr_interface.session_mode = 'immersive-vr'
  # 'bounded-floor' is room scale, 'local-floor' is a standing or sitting
  # experience (it puts you 1.6m above the ground if you have 3DoF headset),
  # whereas as 'local' puts you down at the ARVROrigin.
  # This list means it'll first try to request 'bounded-floor', then
  # fallback on 'local-floor' and ultimately 'local', if nothing else is
  # supported.
  webxr_interface.requested_reference_space_types = 'bounded-floor, local-floor, local'
  # In order to use 'local-floor' or 'bounded-floor' we must also
  # mark the features as required or optional.
  webxr_interface.required_features = 'local-floor'
  webxr_interface.optional_features = 'bounded-floor'

  # This will return false if we're unable to even request the session,
  # however, it can still fail asynchronously later in the process, so we
  # only know if it's really succeeded or failed when our
  # _webxr_session_started() or _webxr_session_failed() methods are called.
  if not webxr_interface.initialize():
    OS.alert("Failed to initialize WebXR")
    return

func _webxr_session_started() -> void:
  $CanvasLayer.visible = false
  # This tells Godot to start rendering to the headset.
  get_viewport().use_xr = true
  # This will be the reference space type you ultimately got, out of the
  # types that you requested above. This is useful if you want the game to
  # work a little differently in 'bounded-floor' versus 'local-floor'.
  print ("Reference space type: " + webxr_interface.reference_space_type)

func _webxr_session_ended() -> void:
  $CanvasLayer.visible = true
  # If the user exits immersive mode, then we tell Godot to render to the web
  # page again.
  get_viewport().use_xr = false

func _webxr_session_failed(message: String) -> void:
  OS.alert("Failed to initialize: " + message)

func _on_left_controller_button_pressed(button: String) -> void:
  print ("Button pressed: " + button)

func _on_left_controller_button_released(button: String) -> void:
  print ("Button release: " + button)

func _try_move(delta_pos: Vector3) -> void:
    var new_pos = $XROrigin3D.global_position + delta_pos
    _move_query.transform = Transform3D(Basis(), new_pos + Vector3(0, 1.2, 0))
    if get_world_3d().direct_space_state.intersect_shape(_move_query, 1).is_empty():
        $XROrigin3D.global_position = new_pos

func _process(delta: float) -> void:
    _update_teleport_target()

    var left_stick = $XROrigin3D/LeftController.get_vector2("thumbstick")
    if left_stick != Vector2.ZERO:
        var cam_basis = $XROrigin3D/XRCamera3D.global_transform.basis
        var forward = -cam_basis.z * left_stick.y
        var strafe = cam_basis.x * left_stick.x
        var direction = (forward + strafe).normalized()
        direction.y = 0
        _try_move(direction * delta * 2.0)

    var right_stick = $XROrigin3D/RightController.get_vector2("thumbstick")
    if right_stick != Vector2.ZERO:
        $XROrigin3D.rotate_y(-right_stick.x * delta * 1.5)

func _update_teleport_target() -> void:
    var camera = $XROrigin3D/XRCamera3D
    var from = camera.global_position
    var to = from + (-camera.global_transform.basis.z * 15.0)

    var query = PhysicsRayQueryParameters3D.create(from, to)
    var result = get_world_3d().direct_space_state.intersect_ray(query)

    if result and result.normal.dot(Vector3.UP) > 0.5:
        _has_teleport_target = true
        _teleport_target = result.position
        $TeleportMarker.visible = true
        $TeleportMarker.global_position = _teleport_target + Vector3(0, 0.03, 0)
    else:
        _has_teleport_target = false
        $TeleportMarker.visible = false

func _do_teleport() -> void:
    if not _has_teleport_target:
        return
    var camera = $XROrigin3D/XRCamera3D
    var cam_offset = camera.global_position - $XROrigin3D.global_position
    cam_offset.y = 0
    $XROrigin3D.global_position = Vector3(
        _teleport_target.x - cam_offset.x,
        _teleport_target.y,
        _teleport_target.z - cam_offset.z
    )

func _webxr_on_select(input_source_id: int) -> void:
  print("Select: " + str(input_source_id))
  # input_source_id 1 = prawy kontroler
  if input_source_id == 1:
    _do_teleport()

func _webxr_on_select_start(input_source_id: int) -> void:
  print("Select Start: " + str(input_source_id))

func _webxr_on_select_end(input_source_id: int) -> void:
  print("Select End: " + str(input_source_id))

func _webxr_on_squeeze(input_source_id: int) -> void:
  print("Squeeze: " + str(input_source_id))

func _webxr_on_squeeze_start(input_source_id: int) -> void:
  print("Squeeze Start: " + str(input_source_id))

func _webxr_on_squeeze_end(input_source_id: int) -> void:
  print("Squeeze End: " + str(input_source_id))
