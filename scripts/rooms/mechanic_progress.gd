extends RefCounted

## Synesthesia V2 progression: room-specific mechanics own denoising; the mask is
## a local reveal/accessibility assist and cannot complete an interactive room.
static func resolve(mask_progress: float, behavior) -> float:
    var mask_value := clampf(mask_progress, 0.0, 1.0)
    if behavior == null or not behavior.has_method("mechanic_progress"):
        return mask_value
    var mechanic := clampf(float(behavior.mechanic_progress()), 0.0, 1.0)
    var weight := 0.22
    if behavior.has_method("brush_assist_weight"):
        weight = clampf(float(behavior.brush_assist_weight()), 0.0, 0.35)
    return clampf(maxf(mechanic, mask_value * weight), 0.0, 1.0)
