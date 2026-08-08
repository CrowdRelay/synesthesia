#![forbid(unsafe_code)]

//! Pure deterministic gameplay primitives for Synesthesia.
//!
//! This crate deliberately has no Godot dependency. The engine/editor remains
//! responsible for authoring and presentation while state machines that benefit
//! from Rust's type system can be tested in isolation.

use std::collections::BTreeMap;

pub const TAP_MAX_MS: i64 = 340;
pub const HOLD_MS: i64 = 560;
pub const TAP_DISTANCE: f32 = 0.042;
pub const HOLD_DISTANCE: f32 = 0.055;
pub const SWIPE_DISTANCE: f32 = 0.16;
pub const SWIPE_MAX_MS: i64 = 950;
pub const DRAG_MIN_STEP: f32 = 0.0035;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Point {
    pub x: f32,
    pub y: f32,
}

impl Point {
    #[must_use]
    pub fn new(x: f32, y: f32) -> Self {
        Self {
            x: x.clamp(0.0, 1.0),
            y: y.clamp(0.0, 1.0),
        }
    }

    #[must_use]
    pub fn delta(self, other: Self) -> Self {
        Self {
            x: self.x - other.x,
            y: self.y - other.y,
        }
    }

    #[must_use]
    pub fn distance(self, other: Self) -> f32 {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        (dx * dx + dy * dy).sqrt()
    }

    #[must_use]
    pub fn midpoint(self, other: Self) -> Self {
        Self::new((self.x + other.x) * 0.5, (self.y + other.y) * 0.5)
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum GestureKind {
    Press,
    Tap,
    Hold,
    Drag,
    Swipe,
    Release,
    TwoFingerStart,
    TwoFinger,
    TwoFingerEnd,
}

impl GestureKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Press => "press",
            Self::Tap => "tap",
            Self::Hold => "hold",
            Self::Drag => "drag",
            Self::Swipe => "swipe",
            Self::Release => "release",
            Self::TwoFingerStart => "two_finger_start",
            Self::TwoFinger => "two_finger",
            Self::TwoFingerEnd => "two_finger_end",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct GestureEvent {
    pub kind: GestureKind,
    pub pointer_id: i64,
    pub start: Point,
    pub point: Point,
    pub delta: Point,
    pub duration_ms: i64,
    pub distance: f32,
    pub velocity: f32,
    pub pointer_count: usize,
    pub spread: f32,
    pub spread_delta: f32,
    pub time_ms: i64,
}

impl GestureEvent {
    fn single(
        kind: GestureKind,
        pointer_id: i64,
        start: Point,
        point: Point,
        duration_ms: i64,
        distance: f32,
        velocity: f32,
        pointer_count: usize,
    ) -> Self {
        Self {
            kind,
            pointer_id,
            start,
            point,
            delta: point.delta(start),
            duration_ms,
            distance,
            velocity,
            pointer_count,
            spread: 0.0,
            spread_delta: 0.0,
            time_ms: 0,
        }
    }
}

#[derive(Clone, Copy, Debug)]
struct PointerState {
    start: Point,
    last: Point,
    start_ms: i64,
    last_ms: i64,
    distance: f32,
    hold_emitted: bool,
}

#[derive(Debug, Default)]
pub struct GestureEngine {
    pointers: BTreeMap<i64, PointerState>,
    two_finger_start_spread: f32,
    two_finger_active: bool,
}

impl GestureEngine {
    pub fn reset(&mut self) {
        self.pointers.clear();
        self.two_finger_start_spread = 0.0;
        self.two_finger_active = false;
    }

    #[must_use]
    pub fn active_pointer_count(&self) -> usize {
        self.pointers.len()
    }

    #[must_use]
    pub fn has_pointer(&self, pointer_id: i64) -> bool {
        self.pointers.contains_key(&pointer_id)
    }

    #[must_use]
    pub fn single_pointer(&self) -> Option<(i64, Point)> {
        if self.pointers.len() != 1 {
            return None;
        }
        self.pointers
            .iter()
            .next()
            .map(|(pointer_id, state)| (*pointer_id, state.last))
    }

    pub fn pointer_down(&mut self, pointer_id: i64, point: Point, now_ms: i64) -> Vec<GestureEvent> {
        self.pointers.insert(
            pointer_id,
            PointerState {
                start: point,
                last: point,
                start_ms: now_ms,
                last_ms: now_ms,
                distance: 0.0,
                hold_emitted: false,
            },
        );
        let mut events = vec![GestureEvent::single(
            GestureKind::Press,
            pointer_id,
            point,
            point,
            0,
            0.0,
            0.0,
            self.pointers.len(),
        )];
        if self.pointers.len() == 2 {
            if let Some((a, b)) = self.two_pointer_points() {
                self.two_finger_start_spread = a.distance(b);
                self.two_finger_active = true;
                events.push(self.two_finger_event(GestureKind::TwoFingerStart, now_ms));
            }
        }
        events
    }

    pub fn pointer_move(&mut self, pointer_id: i64, point: Point, now_ms: i64) -> Vec<GestureEvent> {
        let pointer_count = self.pointers.len();
        let Some(state) = self.pointers.get_mut(&pointer_id) else {
            return Vec::new();
        };
        let previous = state.last;
        let step = point.delta(previous);
        let step_distance = point.distance(previous);
        let previous_ms = state.last_ms;
        state.last = point;
        state.last_ms = now_ms;
        state.distance += step_distance;

        let mut events = Vec::with_capacity(2);
        if step_distance >= DRAG_MIN_STEP {
            let elapsed_ms = (now_ms - state.start_ms).max(1);
            let step_ms = (now_ms - previous_ms).max(1);
            let velocity = step_distance / ((step_ms as f32) / 1000.0);
            let mut event = GestureEvent::single(
                GestureKind::Drag,
                pointer_id,
                state.start,
                point,
                elapsed_ms,
                state.distance,
                velocity,
                pointer_count,
            );
            event.delta = step;
            events.push(event);
        }
        if self.two_finger_active && pointer_count >= 2 {
            events.push(self.two_finger_event(GestureKind::TwoFinger, now_ms));
        }
        events
    }

    pub fn pointer_up(&mut self, pointer_id: i64, point: Point, now_ms: i64) -> Vec<GestureEvent> {
        let Some(state) = self.pointers.get(&pointer_id).copied() else {
            return Vec::new();
        };
        let pointer_count = self.pointers.len();
        let distance = state.distance.max(state.start.distance(point));
        let elapsed_ms = (now_ms - state.start_ms).max(0);
        let velocity = distance / (((elapsed_ms.max(1)) as f32) / 1000.0).max(0.001);
        let mut events = Vec::with_capacity(3);

        if elapsed_ms <= TAP_MAX_MS && distance <= TAP_DISTANCE {
            events.push(GestureEvent::single(
                GestureKind::Tap,
                pointer_id,
                state.start,
                point,
                elapsed_ms,
                distance,
                velocity,
                pointer_count,
            ));
        } else if elapsed_ms <= SWIPE_MAX_MS && distance >= SWIPE_DISTANCE {
            events.push(GestureEvent::single(
                GestureKind::Swipe,
                pointer_id,
                state.start,
                point,
                elapsed_ms,
                distance,
                velocity,
                pointer_count,
            ));
        }
        events.push(GestureEvent::single(
            GestureKind::Release,
            pointer_id,
            state.start,
            point,
            elapsed_ms,
            distance,
            velocity,
            pointer_count,
        ));

        if self.two_finger_active && pointer_count >= 2 {
            events.push(self.two_finger_event(GestureKind::TwoFingerEnd, now_ms));
        }
        self.pointers.remove(&pointer_id);
        if self.pointers.len() < 2 {
            self.two_finger_active = false;
            self.two_finger_start_spread = 0.0;
        }
        events
    }

    pub fn advance(&mut self, now_ms: i64) -> Vec<GestureEvent> {
        let pointer_count = self.pointers.len();
        let mut events = Vec::new();
        for (pointer_id, state) in &mut self.pointers {
            if state.hold_emitted {
                continue;
            }
            let elapsed_ms = now_ms - state.start_ms;
            if elapsed_ms < HOLD_MS || state.distance > HOLD_DISTANCE {
                continue;
            }
            state.hold_emitted = true;
            events.push(GestureEvent::single(
                GestureKind::Hold,
                *pointer_id,
                state.start,
                state.last,
                elapsed_ms,
                state.distance,
                0.0,
                pointer_count,
            ));
        }
        events
    }

    fn two_pointer_points(&self) -> Option<(Point, Point)> {
        let mut points = self.pointers.values().map(|state| state.last);
        Some((points.next()?, points.next()?))
    }

    fn two_finger_event(&self, kind: GestureKind, now_ms: i64) -> GestureEvent {
        let pointer_count = self.pointers.len();
        let (a, b) = self
            .two_pointer_points()
            .unwrap_or((Point::new(0.5, 0.5), Point::new(0.5, 0.5)));
        let midpoint = a.midpoint(b);
        let spread = a.distance(b);
        GestureEvent {
            kind,
            pointer_id: -999,
            start: midpoint,
            point: midpoint,
            delta: Point::default(),
            duration_ms: 0,
            distance: 0.0,
            velocity: 0.0,
            pointer_count,
            spread,
            spread_delta: spread - self.two_finger_start_spread,
            time_ms: now_ms,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn p(x: f32, y: f32) -> Point {
        Point::new(x, y)
    }

    #[test]
    fn tap_and_release_are_emitted() {
        let mut engine = GestureEngine::default();
        engine.pointer_down(1, p(0.5, 0.5), 100);
        let events = engine.pointer_up(1, p(0.51, 0.5), 250);
        assert_eq!(events.iter().map(|event| event.kind).collect::<Vec<_>>(), vec![GestureKind::Tap, GestureKind::Release]);
    }

    #[test]
    fn swipe_is_classified_without_tap() {
        let mut engine = GestureEngine::default();
        engine.pointer_down(1, p(0.1, 0.5), 0);
        engine.pointer_move(1, p(0.35, 0.5), 180);
        let events = engine.pointer_up(1, p(0.5, 0.5), 300);
        assert_eq!(events[0].kind, GestureKind::Swipe);
        assert_eq!(events[1].kind, GestureKind::Release);
    }

    #[test]
    fn hold_is_emitted_once() {
        let mut engine = GestureEngine::default();
        engine.pointer_down(7, p(0.2, 0.2), 0);
        assert!(engine.advance(559).is_empty());
        assert_eq!(engine.advance(560)[0].kind, GestureKind::Hold);
        assert!(engine.advance(900).is_empty());
    }

    #[test]
    fn two_finger_spread_is_deterministic() {
        let mut engine = GestureEngine::default();
        engine.pointer_down(9, p(0.2, 0.5), 0);
        let start = engine.pointer_down(3, p(0.8, 0.5), 1);
        assert_eq!(start.last().map(|event| event.kind), Some(GestureKind::TwoFingerStart));
        let moved = engine.pointer_move(3, p(0.9, 0.5), 10);
        let spread = moved.iter().find(|event| event.kind == GestureKind::TwoFinger).expect("two finger event");
        assert!(spread.spread_delta > 0.09);
    }

    #[test]
    fn input_is_clamped_to_room_space() {
        assert_eq!(Point::new(-1.0, 3.0), Point { x: 0.0, y: 1.0 });
    }
}
