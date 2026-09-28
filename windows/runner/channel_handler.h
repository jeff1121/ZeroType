#ifndef RUNNER_CHANNEL_HANDLER_H_
#define RUNNER_CHANNEL_HANDLER_H_

#include <windows.h>
#include <flutter/binary_messenger.h>

// 建立 Windows channels，呼叫端必須傳入已建立的主視窗。
void SetupChannels(flutter::BinaryMessenger* messenger, HWND window_handle);

// 處理本 App 的 WM_HOTKEY；其他 id 留給既有訊息流程。
bool HandleHotkeyMessage(WPARAM wparam);

// 在 Flutter engine 銷毀前解除熱鍵與事件監聽。
void DisposeHotkeyChannels();

#endif  // RUNNER_CHANNEL_HANDLER_H_
