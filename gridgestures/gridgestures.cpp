#include <algorithm>
#include <cmath>
#include <string>

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/state/WorkspaceState.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>

static HANDLE PHANDLE = nullptr;
static Hyprutils::Signal::CHyprSignalListener beginListener, updateListener, endListener;

struct GridSwipe {
    bool tracking = false;
    bool active = false;
    bool vertical = false;
    Vector2D total{};
    double delta = 0;
    double averageSpeed = 0;
    int speedPoints = 0;
    PHLWORKSPACE start;
    PHLMONITORREF monitor;

    static bool valid(int id) { return id >= 1 && id <= 9; }
    int negativeID() const {
        const int id = start->m_id;
        if (vertical) return id <= 3 ? id : id - 3;
        return (id - 1) % 3 == 0 ? id : id - 1;
    }
    int positiveID() const {
        const int id = start->m_id;
        if (vertical) return id >= 7 ? id : id + 3;
        return (id - 1) % 3 == 2 ? id : id + 1;
    }
    PHLWORKSPACE get(int id) const {
        return valid(id) ? State::workspaceState()->query().id(id).run() : nullptr;
    }
    PHLWORKSPACE ensure(int id) {
        if (auto ws = get(id)) return ws;
        return State::workspaceState()->create(id, monitor->m_id);
    }
    double axisDistance() const {
        static auto gap = CConfigValue<Config::INTEGER>("general:gaps_workspaces");
        return vertical ? monitor->m_size.y + *gap : monitor->m_size.x + *gap;
    }
    Vector2D offset(double value) const {
        return vertical ? Vector2D{0.0, value} : Vector2D{value, 0.0};
    }

    void begin(const IPointer::SSwipeBeginEvent& e) {
        if (e.fingers != 3) return;
        tracking = true;
        active = false;
        total = {};
        delta = 0;
        averageSpeed = 0;
        speedPoints = 0;
        start = Desktop::focusState()->monitor()->m_activeWorkspace;
        monitor = Desktop::focusState()->monitor();
    }

    void update(const IPointer::SSwipeUpdateEvent& e) {
        if (!tracking || e.fingers != 3 || !start || !monitor) return;
        total += e.delta;

        // Lock to the dominant physical axis once enough motion is available.
        if (!active) {
            if (std::abs(total.x) < 5 && std::abs(total.y) < 5) return;
            vertical = std::abs(total.y) > std::abs(total.x);
            active = valid(start->m_id);
            if (!active) return;
        }

        static auto distanceCfg = CConfigValue<Config::INTEGER>("gestures:workspace_swipe_distance");
        static auto invert = CConfigValue<Config::INTEGER>("gestures:workspace_swipe_invert");
        const double distance = std::max<int64_t>(1, *distanceCfg);
        const double movement = vertical ? e.delta.y : e.delta.x;
        const double old = delta;
        delta += *invert ? -movement : movement;
        delta = std::clamp(delta, -distance, distance);
        averageSpeed = (averageSpeed * speedPoints + std::abs(delta - old)) / (++speedPoints);

        const int targetID = delta < 0 ? negativeID() : positiveID();
        if (targetID == start->m_id) {
            delta = 0;
            start->m_renderOffset->setValueAndWarp({});
            g_pHyprRenderer->damageMonitor(monitor.lock());
            return;
        }

        auto target = ensure(targetID);
        const int oppositeID = delta < 0 ? positiveID() : negativeID();
        auto opposite = get(oppositeID);
        if (opposite && opposite != start && opposite != target) {
            opposite->m_forceRendering = false;
            opposite->m_alpha->setValueAndWarp(0.F);
        }

        start->m_forceRendering = true;
        target->m_forceRendering = true;
        target->m_alpha->setValueAndWarp(1.F);
        const double screen = axisDistance();
        const double currentOffset = (-delta / distance) * screen;
        const double targetOffset = currentOffset + (delta < 0 ? -screen : screen);
        start->m_renderOffset->setValueAndWarp(offset(currentOffset));
        target->m_renderOffset->setValueAndWarp(offset(targetOffset));
        start->updateWindowDecos();
        target->updateWindowDecos();
        g_pHyprRenderer->damageMonitor(monitor.lock());
    }

    void end() {
        if (!tracking) return;
        tracking = false;
        if (!active || !start || !monitor) {
            active = false;
            return;
        }

        static auto ratio = CConfigValue<Config::FLOAT>("gestures:workspace_swipe_cancel_ratio");
        static auto distanceCfg = CConfigValue<Config::INTEGER>("gestures:workspace_swipe_distance");
        static auto force = CConfigValue<Config::INTEGER>("gestures:workspace_swipe_min_speed_to_force");
        const double distance = std::max<int64_t>(1, *distanceCfg);
        const int targetID = delta < 0 ? negativeID() : positiveID();
        auto negative = get(negativeID());
        auto positive = get(positiveID());
        const bool cancel = targetID == start->m_id || std::abs(delta) < 2 ||
            (std::abs(delta) < distance * *ratio && (*force == 0 || averageSpeed < *force));

        if (cancel) {
            if (negative && negative != start) *negative->m_renderOffset = offset(-axisDistance());
            if (positive && positive != start) *positive->m_renderOffset = offset(axisDistance());
            *start->m_renderOffset = Vector2D{};
        } else {
            auto target = ensure(targetID);
            const auto oldTargetOffset = target->m_renderOffset->value();
            monitor->changeWorkspace(targetID);
            target->m_renderOffset->setValue(oldTargetOffset);
            target->m_alpha->setValueAndWarp(1.F);
            start->m_renderOffset->setValue(start->m_renderOffset->value());
            *start->m_renderOffset = offset(delta < 0 ? axisDistance() : -axisDistance());
            start->m_alpha->setValueAndWarp(1.F);
            g_pInputManager->unconstrainMouse();
        }

        if (negative) negative->m_forceRendering = false;
        if (positive) positive->m_forceRendering = false;
        start->m_forceRendering = false;
        g_pHyprRenderer->damageMonitor(monitor.lock());
        g_pInputManager->refocus();
        start = nullptr;
        active = false;
    }
} swipe;

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;
    beginListener = Event::bus()->m_events.gesture.swipe.begin.listen(
        [](IPointer::SSwipeBeginEvent e, Event::SCallbackInfo& info) {
            if (e.fingers == 3) { info.cancelled = true; swipe.begin(e); }
        });
    updateListener = Event::bus()->m_events.gesture.swipe.update.listen(
        [](IPointer::SSwipeUpdateEvent e, Event::SCallbackInfo& info) {
            if (e.fingers == 3) { info.cancelled = true; swipe.update(e); }
        });
    endListener = Event::bus()->m_events.gesture.swipe.end.listen(
        [](IPointer::SSwipeEndEvent e, Event::SCallbackInfo& info) {
            if (swipe.tracking) { info.cancelled = true; swipe.end(); }
        });
    return {"gridgestures", "Raw-axis interactive 3x3 workspace gestures", "local", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    beginListener.reset();
    updateListener.reset();
    endListener.reset();
}
