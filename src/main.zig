const std = @import("std");

const frequencies = blk: {
    var freqs: [108]f32 = undefined;
    freqs[0] = 16.35;
    const factor = std.math.pow(f32, 2, 1.0 / 12.0);
    for (1..freqs.len) |i| {
        freqs[i] = freqs[i - 1] * factor;
    }
    break :blk freqs;
};

const NoteValue = enum { C, CSharp, DFlat, D, DSharp, EFlat, E, F, FSharp, GFlat, G, GSharp, AFlat, A, ASharp, BFlat, B };

const Duration = enum { Whole, Half, Quarter, Eigth, Sixteenth, ThirtySecond, SixtyFourth };

const Note = struct {
    start: f32,
    value: NoteValue,
    duration: Duration = .Quarter,
    octave: u8,
    dotted: bool,

    fn getFrequency(self: *Note) f32 {
        const offset: u8 = switch (self.value) {
            .C => 0,
            .CSharp, .DFlat => 1,
            .D => 2,
            .DSharp, .EFlat => 3,
            .E => 4,
            .F => 5,
            .FSharp, .GFlat => 6,
            .G => 7,
            .GSharp, .AFlat => 8,
            .A => 9,
            .ASharp, .BFlat => 10,
            .B => 11,
        };
        const index = self.octave * 12 + offset;
        return frequencies[index];
    }

    fn getBeats(self: @This()) f32 {
        const factor: f32 = if (self.dotted) 1.5 else 1.0;
        const val: f32 = switch (self.duration) {
            .Whole => 4.0,
            .Half => 2.0,
            .Quarter => 1.0,
            .Eigth => 1.0 / 2.0,
            .Sixteenth => 1.0 / 4.0,
            .ThirtySecond => 1.0 / 8.0,
            .SixtyFourth => 1.0 / 16.0,
        };
        return val * factor;
    }
};

const MelodyBuilder = struct {
    notes: std.ArrayListUnmanaged(Note),
    position: f32 = 1,

    fn init() @This() {
        const notes: std.ArrayListUnmanaged(Note) = .{};
        return MelodyBuilder{
            .notes = notes,
        };
    }

    fn add(
        self: *MelodyBuilder,
        arena: std.mem.Allocator,
        value: NoteValue,
        duration: Duration,
        octave: u8,
        dotted: bool,
    ) !void {
        const note = Note{
            .value = value,
            .duration = duration,
            .octave = octave,
            .start = self.position,
            .dotted = dotted,
        };
        try self.notes.append(arena, note);
        self.position += note.getBeats();
    }

    fn getNotes(self: *MelodyBuilder) std.ArrayListUnmanaged(Note) {
        return self.notes;
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var file = try std.fs.cwd().createFile("out.wav", .{ .read = true });
    defer file.close();

    const bpm = 120;
    const bars = 8;
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

    var builder = MelodyBuilder.init();

    try builder.add(allocator, .E, .Quarter, 5, false);
    try builder.add(allocator, .B, .Eigth, 4, false);
    try builder.add(allocator, .C, .Eigth, 5, false);
    try builder.add(allocator, .D, .Quarter, 5, false);
    try builder.add(allocator, .C, .Eigth, 5, false);
    try builder.add(allocator, .B, .Eigth, 4, false);
    try builder.add(allocator, .A, .Quarter, 4, false);
    try builder.add(allocator, .A, .Eigth, 4, false);
    try builder.add(allocator, .C, .Eigth, 5, false);
    try builder.add(allocator, .E, .Quarter, 5, false);
    try builder.add(allocator, .D, .Eigth, 5, false);
    try builder.add(allocator, .C, .Eigth, 5, false);
    try builder.add(allocator, .B, .Quarter, 4, false);
    try builder.add(allocator, .B, .Eigth, 4, false);
    try builder.add(allocator, .C, .Eigth, 5, false);
    try builder.add(allocator, .D, .Quarter, 5, false);
    try builder.add(allocator, .E, .Quarter, 5, false);
    try builder.add(allocator, .C, .Quarter, 5, false);
    try builder.add(allocator, .A, .Half, 4, true);
    try builder.add(allocator, .A, .Eigth, 4, false);
    try builder.add(allocator, .D, .Eigth, 5, false);
    try builder.add(allocator, .F, .Eigth, 5, false);
    try builder.add(allocator, .A, .Eigth, 5, false);
    try builder.add(allocator, .A, .Eigth, 5, false);
    try builder.add(allocator, .G, .Eigth, 5, false);
    try builder.add(allocator, .F, .Eigth, 5, false);
    try builder.add(allocator, .E, .Quarter, 5, true);
    try builder.add(allocator, .C, .Eigth, 5, false);
    try builder.add(allocator, .E, .Quarter, 5, false);
    try builder.add(allocator, .D, .Eigth, 5, false);
    try builder.add(allocator, .C, .Eigth, 5, false);
    try builder.add(allocator, .B, .Quarter, 4, false);
    try builder.add(allocator, .B, .Eigth, 4, false);
    try builder.add(allocator, .C, .Eigth, 5, false);
    try builder.add(allocator, .D, .Quarter, 5, false);
    try builder.add(allocator, .E, .Quarter, 5, false);
    try builder.add(allocator, .C, .Quarter, 5, false);
    try builder.add(allocator, .A, .Whole, 4, true);

    const notes = builder.getNotes().items;

    var current_note: usize = 0;

    for (0..number_of_samples) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / sample_rate;
        const beat = t / secs_per_beat + 1;

        if (beat >= notes[current_note].start + notes[current_note].getBeats()) {
            current_note += 1;
        }

        const y: f32 = std.math.sin(t * notes[current_note].getFrequency() * 2.0 * std.math.pi);
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
