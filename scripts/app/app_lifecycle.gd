extends RefCounted

const MenuRuntimeGuard := preload("res://scripts/app/menu_runtime_guard.gd")
const UIFactory := preload("res://scripts/ui/ui_factory.gd")

# Keeps lifecycle suspend/resume and shutdown concerns out of the gameplay root.
static func handle(app: Node, what: int) -> void:
    if what == Window.NOTIFICATION_WM_GO_BACK_REQUEST:
        app._handle_back_request()
        return
    if what == Window.NOTIFICATION_WM_CLOSE_REQUEST or what == Node.NOTIFICATION_APPLICATION_PAUSED:
        if what == Node.NOTIFICATION_APPLICATION_PAUSED and app.room_flow != null:
            app.room_timer_paused_by_background = app.room_timer_running
            app.room_flow.pause_room_timer()
        if app.room != null and is_instance_valid(app.room):
            app._save_progress()
        else:
            app._save_album_state()
    if what == Node.NOTIFICATION_APPLICATION_PAUSED:
        MenuRuntimeGuard.suspend_for_background(app.experience_surface, app.ui_root, app.room_layer, app.audio_director, app.adaptive_performance)
    elif what == Node.NOTIFICATION_APPLICATION_RESUMED:
        MenuRuntimeGuard.resume_from_background(app.experience_surface, app.ui_root, app.room_layer, app.audio_director, app.adaptive_performance)
        if app.room_timer_paused_by_background and app.room_flow != null:
            app.room_flow.resume_room_timer()
        app.room_timer_paused_by_background = false
        app.reward_flow.refresh_link_context_after_resume()

static func shutdown(app: Node) -> void:
    UIFactory.release_runtime_caches()
    if app.save_timer != null and not app.save_timer.is_stopped():
        app.save_timer.stop()
    if app.reward_client != null and is_instance_valid(app.reward_client) and app.reward_client.has_method("shutdown"):
        app.reward_client.shutdown()
    if app.asset_preloader != null and is_instance_valid(app.asset_preloader) and app.asset_preloader.has_method("drain"):
        app.asset_preloader.drain()
