import sys, mido

A4 = 440.0
NOTE_A4 = 69

def note_name(note):
    """Convert MIDI note number to note name like C4, A#3, etc."""
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    return f"{names[note % 12]}{note // 12 - 1}"

def ticks_to_beats(ticks, ticks_per_beat):
    return ticks / ticks_per_beat

def preview_track(track, ticks_per_beat):
    notes = []
    for msg in track:
        if msg.type == "note_on" and msg.velocity > 0:
            notes.append(note_name(msg.note))
            if len(notes) >= 8:
                break
    return " ".join(notes) if notes else "(no notes)"

def midi_to_tracker(midi_file, track_index):
    mid = mido.MidiFile(midi_file)
    ticks_per_beat = mid.ticks_per_beat
    track = mid.tracks[track_index]

    time_beats = 0
    events = []
    active_notes = {}

    for i, msg in enumerate(track):
        time_beats += ticks_to_beats(msg.time, ticks_per_beat)

        if msg.type == "note_on" and msg.velocity > 0:
            # insert rest if needed
            if time_beats > 0:
                events.append(f"OFF {time_beats:.3f}")
                time_beats = 0

            note = msg.note
            active_notes[note] = 0  # duration counter

        elif msg.type in ("note_off", "note_on") and (msg.velocity == 0 or msg.type == "note_off"):
            note = msg.note
            if note in active_notes:
                duration = time_beats
                events.append(f"ON {note_name(note)} {duration:.3f}")
                del active_notes[note]
                time_beats = 0

    events.append("END")
    return "\n".join(events)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python mid2track.py input.mid")
        sys.exit(1)

    infile = sys.argv[1]
    mid = mido.MidiFile(infile)

    print(f"MIDI file: {infile}")
    print(f"Tracks: {len(mid.tracks)}")

    # Preview each track
    for i, track in enumerate(mid.tracks):
        preview = preview_track(track, mid.ticks_per_beat)
        print(f"[{i}] {track.name or '(unnamed)'} - {len(track)} events - Notes: {preview}")

    # Ask user which one
    choice = int(input("Select track index to convert: "))

    data = midi_to_tracker(infile, choice)
    outfile = infile + f".track{choice}.track"
    with open(outfile, "w") as f:
        f.write(data)

    print(f"[OK] Track {choice} converted → {outfile}")
