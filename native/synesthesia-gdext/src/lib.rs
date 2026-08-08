use godot::prelude::*;
use synesthesia_core::{GestureEngine, GestureEvent, Point};

struct SynesthesiaExtension;

#[gdextension]
unsafe impl ExtensionLibrary for SynesthesiaExtension {}

#[derive(GodotClass)]
#[class(init)]
struct SynesthesiaGestureCore {
    engine: GestureEngine,
}

#[godot_api]
impl SynesthesiaGestureCore {
    #[func]
    fn reset(&mut self) {
        self.engine.reset();
    }

    #[func]
    fn active_pointer_count(&self) -> i64 {
        i64::try_from(self.engine.active_pointer_count()).unwrap_or(i64::MAX)
    }

    #[func]
    fn has_pointer(&self, pointer_id: i64) -> bool {
        self.engine.has_pointer(pointer_id)
    }

    #[func]
    fn single_pointer(&self) -> VarDictionary {
        let mut result = VarDictionary::new();
        if let Some((pointer_id, point)) = self.engine.single_pointer() {
            result.set("pointer_id", pointer_id);
            result.set("point", to_vector(point));
        }
        result
    }

    #[func]
    fn pointer_down(
        &mut self,
        pointer_id: i64,
        point: Vector2,
        now_ms: i64,
    ) -> Array<VarDictionary> {
        events_to_array(
            self.engine
                .pointer_down(pointer_id, from_vector(point), now_ms),
        )
    }

    #[func]
    fn pointer_move(
        &mut self,
        pointer_id: i64,
        point: Vector2,
        now_ms: i64,
    ) -> Array<VarDictionary> {
        events_to_array(
            self.engine
                .pointer_move(pointer_id, from_vector(point), now_ms),
        )
    }

    #[func]
    fn pointer_up(&mut self, pointer_id: i64, point: Vector2, now_ms: i64) -> Array<VarDictionary> {
        events_to_array(
            self.engine
                .pointer_up(pointer_id, from_vector(point), now_ms),
        )
    }

    #[func]
    fn advance(&mut self, now_ms: i64) -> Array<VarDictionary> {
        events_to_array(self.engine.advance(now_ms))
    }
}

fn from_vector(value: Vector2) -> Point {
    Point::new(value.x, value.y)
}

fn to_vector(value: Point) -> Vector2 {
    Vector2::new(value.x, value.y)
}

fn events_to_array(events: Vec<GestureEvent>) -> Array<VarDictionary> {
    let mut result = Array::new();
    for event in events {
        result.push(&event_to_dictionary(event));
    }
    result
}

fn event_to_dictionary(event: GestureEvent) -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("kind", event.kind.as_str());
    result.set("pointer_id", event.pointer_id);
    result.set("start", to_vector(event.start));
    result.set("point", to_vector(event.point));
    result.set("delta", to_vector(event.delta));
    result.set("duration_ms", event.duration_ms);
    result.set("distance", event.distance);
    result.set("velocity", event.velocity);
    result.set(
        "pointer_count",
        i64::try_from(event.pointer_count).unwrap_or(i64::MAX),
    );
    if event.kind.as_str().starts_with("two_finger") {
        result.set("spread", event.spread);
        result.set("spread_delta", event.spread_delta);
        result.set("time_ms", event.time_ms);
    }
    result
}
