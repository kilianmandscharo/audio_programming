const std = @import("std");

pub fn main() !void {
    var file = try std.fs.cwd().createFile("out.wav", .{ .read = true });
    defer file.close();

    const fmt_chunk_size: u32 = 16;
    const audio_format: u16 = 1;
    const number_of_channels: u16 = 1;
    const sample_rate: u32 = 44100;
    const bits_per_sample: u16 = 16;
    const bytes_per_bloc: u16 = number_of_channels * bits_per_sample / 8;
    const bytes_per_sec: u32 = sample_rate * bytes_per_bloc;

    const duration = 2;
    const data_size: u32 = duration * bytes_per_sec;

    const file_size: u32 = 12 + 24 + 8 + data_size - 8;

    try writeString(&file, "RIFF");
    try writeInt(u32, &file, file_size);
    try writeString(&file, "WAVE");

    try writeString(&file, "fmt ");
    try writeInt(u32, &file, fmt_chunk_size);
    try writeInt(u16, &file, audio_format);
    try writeInt(u16, &file, number_of_channels);
    try writeInt(u32, &file, sample_rate);
    try writeInt(u32, &file, bytes_per_sec);
    try writeInt(u16, &file, bytes_per_bloc);
    try writeInt(u16, &file, bits_per_sample);

    try writeString(&file, "data");
    try writeInt(u32, &file, data_size);

    for (0..duration * sample_rate) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / sample_rate;
        const y: f32 = 0.25 * std.math.sin(t * 440.0 * 2.0 * 3.1415);
        std.debug.print("x = {d}, y = {d}\n", .{ t, y });
        const sample: i16 = @intFromFloat(y * std.math.maxInt(i16));
        try writeInt(i16, &file, sample);
    }
}

fn writeString(file: *std.fs.File, val: []const u8) !void {
    _ = try file.write(val);
}

fn writeInt(T: type, file: *std.fs.File, val: T) !void {
    var buf: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &buf, val, .little);
    _ = try file.write(&buf);
}
