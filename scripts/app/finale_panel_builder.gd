extends Node

# Owns the finale surface the player actually sees: the full Signal card, its
# degraded fallback, and the verification that one of them really reached the
# screen. Reward networking, the link-failure latch and every card callback stay
# in MainRewardFlow; this node only decides which panel is mounted and visible.

const SIGNAL_FINALE_CARD_PATH := "res://scripts/ui/signal_finale_card.gd"
const SIGNAL_FINALE_FALLBACK_PATH := "res://scripts/ui/signal_finale_fallback_card.gd"
const WebE2EProbe := preload("res://scripts/app/web_e2e_probe.gd")

var app: Node
var flow: Node

func bind(owner: Node, reward_flow: Node) -> void:
    app = owner
    flow = reward_flow

func _reward_panel_ready() -> bool:
    return (
        app.reward_panel != null
        and is_instance_valid(app.reward_panel)
        and app.reward_panel.is_inside_tree()
        and app.reward_panel.has_method("is_ready_for_input")
        and bool(app.reward_panel.is_ready_for_input())
    )

func _reward_panel_visibly_ready() -> bool:
    return (
        _reward_panel_ready()
        and app.reward_panel.is_visible_in_tree()
        and app.reward_panel.modulate.a >= 0.94
    )

func _force_reward_panel_visible() -> bool:
    if not _reward_panel_ready():
        return false
    app.reward_panel.show()
    # Never let a stalled cosmetic fade leave an input-ready finale at alpha zero.
    app.reward_panel.modulate.a = 1.0
    return app.reward_panel.is_visible_in_tree()

func _show_reward_panel() -> void:
    # Replay/restore reuses only an input-ready finale; otherwise rebuild it.
    if _reward_panel_ready():
        app.reward_panel.show()
        return
    if app.reward_panel != null and is_instance_valid(app.reward_panel):
        app._remove_modal(app.reward_panel)
    app.reward_panel = null
    # The finale can be opened directly from a persisted 11/11 journey. In that
    # path _begin_experience() intentionally skips gameplay startup, so the
    # reward client may not exist yet. Bring it online here as well and let the
    # normal run-start callback reconcile all locally completed rooms.
    if app.reward_client == null:
        flow._configure_reward_client()
    flow._prepare_finale_background()
    # Nothing between the background and the card may abort construction: the
    # background is already on screen, so a failure here leaves the animation
    # running with no final menu. Outro audio is cosmetic; the finale is not.
    if app.menu_soundscape != null and is_instance_valid(app.menu_soundscape):
        app.SoundscapeRuntime.enter_outro(app.menu_soundscape, app.music_level, app.noise_level, app.quiet_mode)
    # Persisted 11/11 journeys intentionally skip gameplay runtime. The finale
    # must therefore never assume HUD exists: otherwise the animated background
    # survives while the actual final menu aborts before it is constructed.
    if app.hud != null and is_instance_valid(app.hud):
        app.hud.visible = false
    var SignalFinaleCardScript: Script = flow._runtime_script(SIGNAL_FINALE_CARD_PATH)
    if SignalFinaleCardScript == null:
        _install_reward_fallback("Pełny finał nie załadował się poprawnie. Wynik pozostaje zapisany.")
        return
    app.reward_panel = SignalFinaleCardScript.new()
    app.reward_panel.name = "SignalFinaleCard"
    app.ui_root.attach(app.reward_panel, 40)
    # Verify across several rendered frames. A single deferred check can race
    # desktop layout/focus construction; the fallback itself also contains the
    # e-mail form, so every completed/replay path remains actionable.
    call_deferred("_verify_reward_panel_ready")
    if app.gameplay_telemetry != null:
        var summary: Dictionary = app.ProgressMetrics.completion_summary(app.release_entries, app.album_state)
        app.gameplay_telemetry.complete_journey(
            int(summary.get("elapsed_ms", 0)),
            int(summary.get("echoes_found", 0)),
            int(summary.get("echoes_total", 0)),
        )
    app.reward_panel.configure(
        bool(app.album_state.get("server_album_completed", false)),
        app.ProgressStoreScript.load_reward(),
        app.ProgressMetrics.completion_summary(app.release_entries, app.album_state),
        app.completion_context,
    )
    if bool(app.album_state.get("server_album_completed", false)) and app.reward_client != null and app.completion_context.is_empty():
        # Refresh mutable handoff/link context with a fresh idempotency key.
        app.reward_client.refresh_completion_context(int(app.album_state.get("total_elapsed_ms", 0)))
    app.reward_panel.draw_entry_requested.connect(flow._submit_reward_claim_values)
    app.reward_panel.leaderboard_publish_requested.connect(flow._publish_leaderboard)
    app.reward_panel.leaderboard_refresh_requested.connect(flow._refresh_leaderboard)
    app.reward_panel.signal_context_refresh_requested.connect(flow._refresh_signal_context)
    app.reward_panel.signal_handoff_requested.connect(flow._issue_signal_handoff)
    app.reward_panel.signal_link_retry_requested.connect(flow._retry_signal_link)
    app.reward_panel.reset_requested.connect(app._confirm_reset_album)
    app.reward_panel.album_mode_requested.connect(app._show_album_archive)
    # UI first, network second. start_run() is idempotent for a restored run and
    # _on_run_started() reconciles every locally completed room before complete.
    # This makes replay/persisted completion registration independent of HUD/menu
    # runtime and keeps a visible finale even when CrowdRelay is temporarily down.
    if app.reward_client != null:
        app.reward_client.start_run()
    else:
        # Nothing will ever confirm completion, so the CTA must not sit disabled.
        flow._link_state.mark_failed(app.reward_panel)
    flow._link_state.apply(app.reward_panel)
    flow._refresh_leaderboard()

func _verify_reward_panel_ready() -> void:
    # Verify what the player can actually see, not merely that input controls
    # were allocated. The full finale intentionally fades in for 300 ms, so use
    # a monotonic deadline instead of a fixed six-frame check (which could pass
    # while modulate.a was still zero).
    var deadline_ms: int = Time.get_ticks_msec() + 650
    while Time.get_ticks_msec() < deadline_ms:
        await get_tree().process_frame
        if _reward_panel_visibly_ready():
            WebE2EProbe.emit("finale", {"ready":true,"fallback":false,"forced":false})
            return
    if _force_reward_panel_visible():
        await get_tree().process_frame
        if _reward_panel_visibly_ready():
            WebE2EProbe.emit("finale", {"ready":true,"fallback":false,"forced":true})
            return
    _install_reward_fallback("Finał przełączył się w tryb bezpieczny. Wynik jest zachowany lokalnie i może zostać zsynchronizowany.")

func _install_reward_fallback(message: String) -> void:
    if app.reward_panel != null and is_instance_valid(app.reward_panel):
        app._remove_modal(app.reward_panel)
        app.reward_panel = null
    var FallbackScript: Script = flow._runtime_script(SIGNAL_FINALE_FALLBACK_PATH)
    if FallbackScript == null:
        app._show_fatal_error(message)
        return
    app.reward_panel = FallbackScript.new()
    app.reward_panel.name = "SignalFinaleFallbackCard"
    app.ui_root.attach(app.reward_panel, 40)
    app.reward_panel.configure(
        bool(app.album_state.get("server_album_completed", false)),
        app.ProgressStoreScript.load_reward(),
        app.ProgressMetrics.completion_summary(app.release_entries, app.album_state),
        app.completion_context,
        message,
    )
    app.reward_panel.draw_entry_requested.connect(flow._submit_reward_claim_values)
    app.reward_panel.signal_context_refresh_requested.connect(flow._refresh_signal_context)
    app.reward_panel.signal_handoff_requested.connect(flow._issue_signal_handoff)
    app.reward_panel.signal_link_retry_requested.connect(flow._retry_signal_link)
    app.reward_panel.reset_requested.connect(app._confirm_reset_album)
    app.reward_panel.album_mode_requested.connect(app._show_album_archive)
    flow._link_state.apply(app.reward_panel)
    WebE2EProbe.emit("finale", {"ready":true,"fallback":true})
