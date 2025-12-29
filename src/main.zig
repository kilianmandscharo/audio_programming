const std = @import("std");

const Note = struct {
    frequency: f32,
    start: f32,
    duration: f32,
};

pub fn main() !void {
    var file = try std.fs.cwd().createFile("out.wav", .{ .read = true });
    defer file.close();

    const bpm = 120;
    const bars = 4;
    const beats = bars * 4;
    const duration: u32 = std.math.round(@as(f32, @floatFromInt(beats)) / @as(f32, @floatFromInt(bpm)) * 60);
    const secs_per_beat = @as(f32, @floatFromInt(duration)) / @as(f32, @floatFromInt(beats));

    const fmt_chunk_size: u32 = 16;
    const audio_format: u16 = 1;
    const number_of_channels: u16 = 1;
    const sample_rate: u32 = 44100;
    const bits_per_sample: u16 = 16;
    const bytes_per_bloc: u16 = number_of_channels * bits_per_sample / 8;
    const bytes_per_sec: u32 = sample_rate * bytes_per_bloc;

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

    const number_of_samples = duration * sample_rate;

    const notes: []const Note = &.{
        .{
            .start = 1,
            .duration = 1,
            .frequency = 659.25,
        },
        .{
            .start = 2,
            .duration = 0.5,
            .frequency = 493.88,
        },
        .{
            .start = 2.5,
            .duration = 0.5,
            .frequency = 523.25,
        },
        .{
            .start = 3,
            .duration = 1,
            .frequency = 587.33,
        },
        .{
            .start = 4,
            .duration = 0.5,
            .frequency = 523.25,
        },
        .{
            .start = 4.5,
            .duration = 0.5,
            .frequency = 493.88,
        },
        .{
            .start = 5,
            .duration = 1,
            .frequency = 440.00,
        },
        .{
            .start = 6,
            .duration = 0.5,
            .frequency = 440.00,
        },
        .{
            .start = 6.5,
            .duration = 0.5,
            .frequency = 523.25,
        },
        .{
            .start = 7,
            .duration = 1,
            .frequency = 659.25,
        },

        .{
            .start = 8,
            .duration = 0.5,
            .frequency = 587.33,
        },
        .{
            .start = 8.5,
            .duration = 0.5,
            .frequency = 523.25,
        },
        .{
            .start = 9,
            .duration = 1,
            .frequency = 493.88,
        },
        .{
            .start = 10,
            .duration = 0.5,
            .frequency = 493.88,
        },
        .{
            .start = 10.5,
            .duration = 0.5,
            .frequency = 523.25,
        },
        .{
            .start = 11,
            .duration = 1,
            .frequency = 587.33,
        },
        .{
            .start = 12,
            .duration = 1,
            .frequency = 659.25,
        },
        .{
            .start = 13,
            .duration = 1,
            .frequency = 523.25,
        },
        .{
            .start = 14,
            .duration = 3,
            .frequency = 440.00,
        },
    };

    var current_note: usize = 0;

    for (0..number_of_samples) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / sample_rate;
        const beat = t / secs_per_beat + 1;

        if (beat >= notes[current_note].start + notes[current_note].duration) {
            current_note += 1;
        }

        const y: f32 = std.math.sin(t * notes[current_note].frequency * 2.0 * std.math.pi);
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
