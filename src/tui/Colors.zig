pub const Colors = @This();

pub const cyan = "\x1b[36m";
pub const reset = "\x1b[0m";
pub const yellow = "\x1b[33m";
pub const purple = "\x1b[35m";
pub const blue = "\x1b[34m";
pub const green = "\x1b[32m";
pub const red = "\x1b[31m";
pub const gray = "\x1b[90m";
pub const bold = "\x1b[1m";
pub const italic = "\x1b[3m";
pub const underline = "\x1b[4m";
pub const blink = "\x1b[5m";
pub const reverse = "\x1b[7m";
pub const hidden = "\x1b[8m";

pub const palletes = Colors{};

pub const Fns = struct {
    pub fn cyan(comptime str: []const u8) []const u8 {
        return Colors.cyan ++ str ++ Colors.reset;
    }
    pub fn yellow(comptime str: []const u8) []const u8 {
        return Colors.yellow ++ str ++ Colors.reset;
    }
    pub fn purple(comptime str: []const u8) []const u8 {
        return Colors.purple ++ str ++ Colors.reset;
    }
    pub fn blue(comptime str: []const u8) []const u8 {
        return Colors.blue ++ str ++ Colors.reset;
    }
    pub fn green(comptime str: []const u8) []const u8 {
        return Colors.green ++ str ++ Colors.reset;
    }
    pub fn red(comptime str: []const u8) []const u8 {
        return Colors.red ++ str ++ Colors.reset;
    }
    pub fn gray(comptime str: []const u8) []const u8 {
        return Colors.gray ++ str ++ Colors.reset;
    }
    pub fn bold(comptime str: []const u8) []const u8 {
        return Colors.bold ++ str ++ Colors.reset;
    }
    pub fn italic(comptime str: []const u8) []const u8 {
        return Colors.italic ++ str ++ Colors.reset;
    }
    pub fn underline(comptime str: []const u8) []const u8 {
        return Colors.underline ++ str ++ Colors.reset;
    }
    pub fn blink(comptime str: []const u8) []const u8 {
        return Colors.blink ++ str ++ Colors.reset;
    }
    pub fn reverse(comptime str: []const u8) []const u8 {
        return Colors.reverse ++ str ++ Colors.reset;
    }
    pub fn hidden(comptime str: []const u8) []const u8 {
        return Colors.hidden ++ str ++ Colors.reset;
    }
};
