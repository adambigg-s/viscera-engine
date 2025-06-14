// this program is only valid for Windows at the moment i was looking for
// something like Rust's 'crossterm' library, but the Zig ecosystem is really
// small and there isn't any terminal library powerful enough yet for this so i
// am just using Windows API direct

pub const WinError = error{
    NullResponse,
    Recoverable,
};

pub fn showCursor() void {
    while (ShowCursor(win_not_false) < 0) {
        continue;
    }
}

pub fn hideCursor() void {
    while (ShowCursor(win_false) >= 0) {
        continue;
    }
}

pub fn getCursorPosition() !struct { i32, i32 } {
    var point: WinPoint = undefined;
    const response = GetCursorPos(&point);
    if (response == win_false) {
        return WinError.Recoverable;
    }

    return .{ @intCast(point.x), @intCast(point.y) };
}

pub fn getTerminalDimensionsChar() !struct { usize, usize } {
    var console_info: WinConsoleInfo = undefined;
    const handle = GetStdHandle(win_std_handle);
    const response = GetConsoleScreenBufferInfo(handle, &console_info);
    if (response == win_false) {
        return WinError.NullResponse;
    }

    const width_signed, const height_signed = .{
        console_info.window_size.x - 1,
        console_info.window_size.y - 1,
    };
    const width: u16, const height: u16 = .{ @bitCast(width_signed), @bitCast(height_signed) };

    return .{ @as(usize, width), @as(usize, height) };
}

pub fn getFontSize() !struct { usize, usize } {
    const handle = GetStdHandle(win_std_handle);
    const size = GetConsoleFontSize(handle, 0);

    const width: u16, const height: u16 = .{ @intCast(size.x), @intCast(size.y) };

    return .{ @as(usize, width), @as(usize, height) };
}

pub fn getTerminalDimensionsPixel() !struct { usize, usize } {
    var rectangle: WinLongRect = undefined;
    const handle = GetConsoleWindow();
    const response = GetClientRect(handle, &rectangle);
    if (response == win_false) {
        return WinError.NullResponse;
    }

    const width_signed, const height_signed = .{
        rectangle.right - rectangle.left,
        rectangle.bottom - rectangle.top,
    };
    const width: u32, const height: u32 = .{ @bitCast(width_signed), @bitCast(height_signed) };

    return .{ @as(usize, width), @as(usize, height) };
}

pub fn setCursorPos(x: usize, y: usize) !void {
    const response = SetCursorPos(@intCast(x), @intCast(y));
    if (response == win_false) {
        return WinError.NullResponse;
    }
}

pub fn getSTDHandle() WinHandle {
    return GetStdHandle(win_std_handle);
}

pub fn getConsoleScreenBufferInfo() !WinConsoleInfo {
    const handle = getSTDHandle();
    var info: WinConsoleInfo = undefined;
    const response = GetConsoleScreenBufferInfo(handle, &info);
    if (response == win_false) {
        return WinError.Recoverable;
    }

    return info;
}

pub fn getKeyState(key_code: comptime_int) bool {
    return GetAsyncKeyState(@intCast(key_code)) != win_false;
}

pub const WinPoint = extern struct {
    x: WinInt,
    y: WinInt,
};

pub const WinCoord = extern struct {
    x: WinShort,
    y: WinShort,
};

// https://learn.microsoft.com/en-us/windows/console/small-rect-str
pub const WinSmallRect = extern struct {
    left: WinShort,
    right: WinShort,
    top: WinShort,
    bottom: WinShort,
};

// https://learn.microsoft.com/en-us/windows/win32/api/windef/ns-windef-rect
pub const WinLongRect = extern struct {
    left: WinLong,
    top: WinLong,
    right: WinLong,
    bottom: WinLong,
};

// https://learn.microsoft.com/en-us/windows/console/getconsolescreenbufferinfo
pub const WinConsoleInfo = extern struct {
    window_size: WinCoord,
    cursor_pos: WinCoord,
    attributes: WinDWord,
    sr_window: WinSmallRect,
    max_size: WinCoord,
};

// https://learn.microsoft.com/en-us/windows/console/console-font-info-str
pub const WinConsoleFontInfo = extern struct {
    font_index: WinDWord,
    font_char_size: WinCoord,
};

// https://learn.microsoft.com/en-us/windows/console/console-font-infoex
pub const WinConsoleFontInfoEx = extern struct {
    size_of: WinDWord,
    font_index: WinDWord,
    font_size: WinCoord,
    font_family: WinDWord,
    font_weight: WinDWord,
    face_name: [32]u16,
};

// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getasynckeystate
pub const vk_mouse_lbutton = 0x01;
pub const vk_escape = 0x1b;
pub const vk_w = 0x57;
pub const vk_a = 0x41;
pub const vk_s = 0x53;
pub const vk_d = 0x44;
pub const vk_r = 0x52;
pub const vk_f = 0x46;

// https://learn.microsoft.com/en-us/windows/win32/winprog/windows-data-types
const WinBool = i32;
const WinInt = i32;
const WinKeyReturn = i16;
const WinDWord = u32;
const WinHandle = *opaque {};
const WinShort = i16;
const WinLong = i32;

// https://learn.microsoft.com/en-us/windows/console/getstdhandle
const win_std_handle = -11;
const win_false: WinBool = 0;
const win_not_false: WinBool = 999999;
const win_key_false: WinKeyReturn = 0;
const win_console_current: WinBool = win_false;

// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getclientrect
extern "User32" fn GetClientRect(handle: WinHandle, *WinLongRect) WinBool;

// https://learn.microsoft.com/en-us/windows/console/getconsolewindow
extern "Kernel32" fn GetConsoleWindow() WinHandle;

// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getcursorpos
extern "User32" fn GetCursorPos(point: *WinPoint) WinBool;

// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setcursorpos
extern "User32" fn SetCursorPos(x: WinInt, y: WinInt) WinBool;

// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getasynckeystate
extern "User32" fn GetAsyncKeyState(virtual_key: WinInt) WinKeyReturn;

// https://learn.microsoft.com/en-us/windows/console/getstdhandle
extern "Kernel32" fn GetStdHandle(std_handle: WinInt) WinHandle;

// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showcursor
extern "User32" fn ShowCursor(toggle_show: WinBool) WinInt;

// https://learn.microsoft.com/en-us/windows/console/getconsolefontsize
extern "Kernel32" fn GetConsoleFontSize(console_handle: WinHandle, font_index: WinDWord) WinCoord;

// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowrect
extern "User32" fn GetWindowRect(window_handle: WinHandle, rectangle: *WinLongRect) WinBool;

// https://learn.microsoft.com/en-us/windows/console/getconsolescreenbufferinfo
extern "Kernel32" fn GetConsoleScreenBufferInfo(
    console_handle: WinHandle,
    console_info: *WinConsoleInfo,
) WinBool;

// https://learn.microsoft.com/en-us/windows/console/getcurrentconsolefont
extern "Kernel32" fn GetCurrentConsoleFont(
    console_handle: WinHandle,
    max_window: WinBool,
    font_info: *WinConsoleFontInfo,
) WinBool;

// https://learn.microsoft.com/en-us/windows/console/getcurrentconsolefontex
extern "Kernel32" fn GetCurrentConsoleFontEx(
    console_handle: WinHandle,
    max_window: WinBool,
    font_info: *WinConsoleFontInfoEx,
) WinBool;
