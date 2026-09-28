#include "channel_handler.h"

#include <windows.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <variant>

// Keep channels alive for the duration of the app
static std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>>
    g_keyboard_channel;
static std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>>
    g_permission_channel;
static std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>>
    g_overlay_channel;
static std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>>
    g_control_channel;
static std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>>
    g_hotkey_channel;
static std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
    g_hotkey_event_channel;

static HWND g_window_handle = nullptr;
static constexpr int kAppHotkeyId = 1;
static bool g_hotkey_registered = false;
static std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>
    g_hotkey_event_sink;

// Simulates Ctrl+V (Windows paste shortcut) using Win32 SendInput.
// Equivalent to macOS CGEvent Cmd+V in AppDelegate.swift.
static void SimulatePaste() {
  INPUT inputs[4] = {};

  // Key down: Ctrl
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wVk = VK_CONTROL;

  // Key down: V
  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.wVk = 'V';

  // Key up: V
  inputs[2].type = INPUT_KEYBOARD;
  inputs[2].ki.wVk = 'V';
  inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

  // Key up: Ctrl
  inputs[3].type = INPUT_KEYBOARD;
  inputs[3].ki.wVk = VK_CONTROL;
  inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

  SendInput(4, inputs, sizeof(INPUT));
}

static HWND GetTargetHwnd() {
  if (g_window_handle == nullptr) {
    return nullptr;
  }
  HWND root = ::GetAncestor(g_window_handle, GA_ROOT);
  return (root != nullptr) ? root : g_window_handle;
}

bool HandleHotkeyMessage(WPARAM wparam) {
  if (wparam == static_cast<WPARAM>(kAppHotkeyId)) {
    if (g_hotkey_registered && g_hotkey_event_sink) {
      g_hotkey_event_sink->Success(flutter::EncodableValue(flutter::EncodableMap{
          {flutter::EncodableValue("id"), flutter::EncodableValue(kAppHotkeyId)},
      }));
    }
    return true;
  }
  return false;
}

void DisposeHotkeyChannels() {
  if (g_window_handle != nullptr && g_hotkey_registered) {
    ::UnregisterHotKey(GetTargetHwnd(), kAppHotkeyId);
  }
  g_hotkey_registered = false;
  g_hotkey_event_sink.reset();
  if (g_hotkey_channel) g_hotkey_channel->SetMethodCallHandler(nullptr);
  if (g_hotkey_event_channel) g_hotkey_event_channel->SetStreamHandler(nullptr);
  g_hotkey_channel.reset();
  g_hotkey_event_channel.reset();
  g_window_handle = nullptr;
}

void SetupChannels(flutter::BinaryMessenger* messenger, HWND window_handle) {
  g_window_handle = window_handle;

  // ── Keyboard channel ────────────────────────────────────────────────────
  // Handles simulatePaste → Win32 SendInput Ctrl+V
  g_keyboard_channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.zerotype.app/keyboard",
          &flutter::StandardMethodCodec::GetInstance());

  g_keyboard_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "simulatePaste") {
          SimulatePaste();
          result->Success(nullptr);
        } else {
          result->NotImplemented();
        }
      });

  // ── Permission channel ──────────────────────────────────────────────────
  // Windows: SendInput does not require Accessibility permission.
  // Return true for checkAccessibility so the Settings page shows it as granted.
  g_permission_channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.zerotype.app/permission",
          &flutter::StandardMethodCodec::GetInstance());

  g_permission_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "checkAccessibility") {
          // No special permission required on Windows
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "openAccessibilitySettings") {
          // No-op on Windows
          result->Success(nullptr);
        } else {
          result->NotImplemented();
        }
      });

  // ── Overlay channel (stub) ──────────────────────────────────────────────
  // On Windows, overlay is handled by the Flutter RecordingOverlay widget.
  // These stubs prevent MissingPluginException on the Dart side.
  g_overlay_channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.zerotype.app/overlay",
          &flutter::StandardMethodCodec::GetInstance());

  g_overlay_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        result->Success(nullptr);
      });

  // ── Control channel (stub) ──────────────────────────────────────────────
  // On Windows, cancel is triggered directly from the Flutter overlay widget.
  g_control_channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.zerotype.app/control",
          &flutter::StandardMethodCodec::GetInstance());

  g_control_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        result->Success(nullptr);
      });

  // ── 熱鍵註冊 MethodChannel ───────────────────────────────────────────────
  g_hotkey_channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.zerotype.app/hotkey",
          &flutter::StandardMethodCodec::GetInstance());

  g_hotkey_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        HWND hwnd = GetTargetHwnd();

        if (call.method_name() == "register") {
          if (hwnd == nullptr || !::IsWindow(hwnd)) {
            result->Error("invalid_window", "主視窗尚未建立，無法註冊快捷鍵。");
            return;
          }
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("invalid_argument", "快捷鍵引數必須為 map。");
            return;
          }

          int64_t raw_vk = 0;
          auto vk_it = args->find(flutter::EncodableValue("vk"));
          if (vk_it != args->end()) {
            if (const auto* value = std::get_if<int32_t>(&vk_it->second)) {
              raw_vk = *value;
            } else if (const auto* value = std::get_if<int64_t>(&vk_it->second)) {
              raw_vk = *value;
            }
          }
          if (raw_vk < 1 || raw_vk > 0xFE) {
            result->Error("invalid_argument", "vk 必須是有效的 Windows virtual-key 整數。");
            return;
          }
          const UINT vk = static_cast<UINT>(raw_vk);

          UINT fs_modifiers = MOD_NOREPEAT;
          auto mod_it = args->find(flutter::EncodableValue("modifiers"));
          const auto* mod_list = mod_it == args->end()
              ? nullptr : std::get_if<flutter::EncodableList>(&mod_it->second);
          if (!mod_list || mod_list->empty()) {
            result->Error("invalid_argument", "modifiers 必須是非空的字串列表。");
            return;
          }
          for (const auto& mod_val : *mod_list) {
            const auto* mod_str = std::get_if<std::string>(&mod_val);
            if (!mod_str) {
              result->Error("invalid_argument", "修飾鍵必須為字串。");
              return;
            }
            if (*mod_str == "alt") {
              fs_modifiers |= MOD_ALT;
            } else if (*mod_str == "control") {
              fs_modifiers |= MOD_CONTROL;
            } else if (*mod_str == "shift") {
              fs_modifiers |= MOD_SHIFT;
            } else if (*mod_str == "meta") {
              fs_modifiers |= MOD_WIN;
            } else {
              result->Error("invalid_modifier", "不支援的修飾鍵：" + *mod_str);
              return;
            }
          }

          // 同一個 root HWND 只使用 id 1；失敗交由 Dart 復原舊組合。
          const BOOL unregistered = ::UnregisterHotKey(hwnd, kAppHotkeyId);
          if (!unregistered && g_hotkey_registered) {
            const DWORD error_code = ::GetLastError();
            result->Error("hotkey_unregister_failed", std::to_string(error_code));
            return;
          }
          g_hotkey_registered = false;
          const BOOL success = ::RegisterHotKey(hwnd, kAppHotkeyId, fs_modifiers, vk);
          if (!success) {
            DWORD error_code = ::GetLastError();
            g_hotkey_registered = false;
            result->Error(
                "hotkey_register_failed",
                std::to_string(error_code),
                flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("vk"),
                     flutter::EncodableValue(static_cast<int32_t>(vk))},
                    {flutter::EncodableValue("modifiers"), mod_it->second},
                    {flutter::EncodableValue("error_code"),
                     flutter::EncodableValue(static_cast<int64_t>(error_code))},
                }));
            return;
          }

          g_hotkey_registered = true;
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "unregisterAll") {
          if (g_hotkey_registered &&
              (hwnd == nullptr || !::UnregisterHotKey(hwnd, kAppHotkeyId))) {
            const DWORD error_code = hwnd == nullptr
                ? ERROR_INVALID_WINDOW_HANDLE : ::GetLastError();
            result->Error("hotkey_unregister_failed", std::to_string(error_code));
            return;
          }
          g_hotkey_registered = false;
          result->Success(nullptr);
        } else {
          result->NotImplemented();
        }
      });

  // ── 熱鍵觸發 EventChannel ────────────────────────────────────────────────
  g_hotkey_event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          messenger, "com.zerotype.app/hotkey_events",
          &flutter::StandardMethodCodec::GetInstance());

  auto stream_handler = std::make_unique<flutter::StreamHandlerFunctions<>>(
      [](const flutter::EncodableValue*,
         std::unique_ptr<flutter::EventSink<>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        g_hotkey_event_sink = std::move(events);
        return nullptr;
      },
      [](const flutter::EncodableValue*)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        g_hotkey_event_sink = nullptr;
        return nullptr;
      });

  g_hotkey_event_channel->SetStreamHandler(std::move(stream_handler));
}
