const std = @import("std");

const bpm = 120.0;
const secs_per_beat = 60.0 / bpm;
const number_of_channels: u16 = 1;
const sample_rate: u32 = 44100;
const bits_per_sample: u16 = 16;
const bytes_per_bloc: u16 = number_of_channels * bits_per_sample / 8;
const bytes_per_sec: u32 = sample_rate * bytes_per_bloc;
const fade_time: f32 = 0.005;

const frequencies = blk: {
    var freqs: [108]f32 = undefined;
    freqs[0] = 16.35;
    const factor = std.math.pow(f32, 2, 1.0 / 12.0);
    for (1..freqs.len) |i| {
        freqs[i] = freqs[i - 1] * factor;
    }
    break :blk freqs;
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const notes = try createNotes(allocator);
    const duration_in_secs = notes[notes.len - 1].end;
    const data_size: u32 = @intFromFloat(std.math.ceil(duration_in_secs * @as(f32, @floatFromInt(bytes_per_sec))));

    std.debug.print("bpm = {}, duration = {}, data_size = {}\n", .{ bpm, duration_in_secs, data_size });

    const buf: []u8 = try allocator.alloc(u8, data_size);
    try renderNotes(allocator, buf, notes);
    try writeWaveFile(buf);
}

fn getFrequency(value: NoteValue, octave: u8) f32 {
    const offset: u8 = switch (value) {
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
    const index = octave * 12 + offset;
    return frequencies[index];
}

const NoteValue = enum { C, CSharp, DFlat, D, DSharp, EFlat, E, F, FSharp, GFlat, G, GSharp, AFlat, A, ASharp, BFlat, B };

const Note = struct {
    start: f32,
    end: f32,
    duration: f32,
    value: NoteValue,
    frequency: f32,
    octave: u8,
    phase: f32 = 0.0,

    fn new(start: f32, duration_in_beats: f32, value: NoteValue, octave: u8) Note {
        const duration = secs_per_beat * duration_in_beats;
        const end = start + duration;
        return Note{
            .start = start,
            .end = end,
            .duration = duration,
            .value = value,
            .frequency = getFrequency(value, octave),
            .octave = octave,
        };
    }
};

const PartialNote = struct {
    value: NoteValue,
    duration: f32,
    octave: u8,
};

const MelodyBuilder = struct {
    notes: std.ArrayListUnmanaged(Note),
    t: f32 = 0,

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
        duration: f32,
        octave: u8,
    ) !void {
        const note = Note.new(self.t, duration, value, octave);
        try self.notes.append(arena, note);
        self.t += note.duration;
    }

    fn addChord(
        self: *MelodyBuilder,
        arena: std.mem.Allocator,
        chord: []const PartialNote,
    ) !void {
        if (chord.len == 0) return;
        for (chord) |*item| {
            const note = Note.new(self.t, item.duration, item.value, item.octave);
            try self.notes.append(arena, note);
        }
        self.t += self.notes.items[self.notes.items.len - 1].duration;
    }

    fn getNotes(self: *MelodyBuilder) std.ArrayListUnmanaged(Note) {
        return self.notes;
    }
};

fn writeWaveFile(data: []u8) !void {
    var file = try std.fs.cwd().createFile("out.wav", .{ .read = true });
    defer file.close();

    const fmt_chunk_size: u32 = 16;
    const audio_format: u16 = 1;

    const data_len: u32 = @intCast(data.len);
    const file_size: u32 = 12 + 24 + 8 + data_len - 8;

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
    try writeInt(u32, &file, data_len);

    _ = try file.write(data);
}

fn createNotes(arena: std.mem.Allocator) ![]Note {
    var builder = MelodyBuilder.init();

    try builder.addChord(arena, &.{
        PartialNote{ .value = .C, .duration = 4, .octave = 5 },
        PartialNote{ .value = .E, .duration = 4, .octave = 5 },
        PartialNote{ .value = .G, .duration = 4, .octave = 5 },
    });

    try builder.addChord(arena, &.{
        PartialNote{ .value = .E, .duration = 4, .octave = 4 },
        PartialNote{ .value = .GSharp, .duration = 4, .octave = 4 },
        PartialNote{ .value = .B, .duration = 4, .octave = 4 },
    });

    try builder.addChord(arena, &.{
        PartialNote{ .value = .A, .duration = 4, .octave = 4 },
        PartialNote{ .value = .C, .duration = 4, .octave = 5 },
        PartialNote{ .value = .E, .duration = 4, .octave = 5 },
    });

    try builder.addChord(arena, &.{
        PartialNote{ .value = .F, .duration = 4, .octave = 4 },
        PartialNote{ .value = .GSharp, .duration = 4, .octave = 4 },
        PartialNote{ .value = .C, .duration = 4, .octave = 5 },
    });

    // try builder.add(arena, .E, 1, 5);
    // try builder.add(arena, .B, 0.5, 4);
    // try builder.add(arena, .C, 0.5, 5);
    // try builder.add(arena, .D, 1.0, 5);
    // try builder.add(arena, .C, 0.5, 5);
    // try builder.add(arena, .B, 0.5, 4);
    // try builder.add(arena, .A, 1.0, 4);
    // try builder.add(arena, .A, 0.5, 4);
    // try builder.add(arena, .C, 0.5, 5);
    // try builder.add(arena, .E, 1.0, 5);
    // try builder.add(arena, .D, 0.5, 5);
    // try builder.add(arena, .C, 0.5, 5);
    // try builder.add(arena, .B, 1.0, 4);
    // try builder.add(arena, .B, 0.5, 4);
    // try builder.add(arena, .C, 0.5, 5);
    // try builder.add(arena, .D, 1.0, 5);
    // try builder.add(arena, .E, 1.0, 5);
    // try builder.add(arena, .C, 1.0, 5);
    // try builder.add(arena, .A, 3.0, 4);
    // try builder.add(arena, .A, 0.5, 4);
    // try builder.add(arena, .D, 0.5, 5);
    // try builder.add(arena, .F, 0.5, 5);
    // try builder.add(arena, .A, 0.5, 5);
    // try builder.add(arena, .A, 0.5, 5);
    // try builder.add(arena, .G, 0.5, 5);
    // try builder.add(arena, .F, 0.5, 5);
    // try builder.add(arena, .E, 1.5, 5);
    // try builder.add(arena, .C, 0.5, 5);
    // try builder.add(arena, .E, 1.0, 5);
    // try builder.add(arena, .D, 0.5, 5);
    // try builder.add(arena, .C, 0.5, 5);
    // try builder.add(arena, .B, 1.0, 4);
    // try builder.add(arena, .B, 0.5, 4);
    // try builder.add(arena, .C, 0.5, 5);
    // try builder.add(arena, .D, 1.0, 5);
    // try builder.add(arena, .E, 1.0, 5);
    // try builder.add(arena, .C, 1.0, 5);
    // try builder.add(arena, .A, 6.0, 4);

    const notes = builder.getNotes();
    std.sort.pdq(Note, notes.items, {}, notesLessThan);
    return notes.items;
}

fn notesLessThan(context: void, a: Note, b: Note) bool {
    _ = context;
    return a.start < b.start;
}

fn renderNotes(arena: std.mem.Allocator, buf: []u8, notes: []Note) !void {
    if (notes.len == 0) return;

    var index: ?usize = null;
    var current_notes: std.ArrayListUnmanaged(Note) = .{};

    for (0..buf.len / 2) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / sample_rate;

        while (true) {
            for (current_notes.items, 0..) |*note, j| {
                if (t >= note.end) {
                    _ = current_notes.swapRemove(j);
                    break;
                }
            }
            break;
        }

        var next_index = if (index) |idx| idx + 1 else 0;

        if (next_index < notes.len and t >= notes[next_index].start) {
            const start = next_index;
            while (next_index < notes.len and notes[next_index].start == notes[start].start) {
                try current_notes.append(arena, notes[next_index]);
                next_index += 1;
            }

            index = next_index - 1;
        }

        var sum: f32 = 0;
        for (current_notes.items) |*note| {
            var envelope: f32 = 1.0;
            if (t < note.start + fade_time) {
                envelope = (t - note.start) / fade_time;
            } else if (t > note.end - fade_time) {
                envelope = (note.end - t) / fade_time;
            }
            const y: f32 = envelope * std.math.sin(note.phase);
            note.phase += 2 * std.math.pi * note.frequency / sample_rate;
            note.phase = @rem(note.phase, std.math.pi * 2);
            sum += y;
        }

        if (current_notes.items.len > 0) {
            sum /= @as(f32, @floatFromInt(current_notes.items.len));
        }

        sum = std.math.clamp(sum, -1.0, 1.0);

        const sample: i16 = @intFromFloat(sum * std.math.maxInt(i16));
        const raw: u16 = @bitCast(sample);
        const offset = i * 2;
        buf[offset] = @truncate(raw);
        buf[offset + 1] = @truncate(raw >> 8);
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
