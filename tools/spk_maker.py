import struct

# Mapping note letters to semitone offsets
NOTE_OFFSETS = {
    "C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3,
    "E": 4, "F": 5, "F#": 6, "GB": 6, "G": 7, "G#": 8,
    "AB": 8, "A": 9, "A#": 10, "BB": 10, "B": 11
}

def note_name_to_midi(note_name: str) -> int:
    note_name = note_name.upper()
    if len(note_name) < 2:
        raise ValueError("Invalid note name: " + note_name)
    if note_name[1] in ("#", "B"):
        letter = note_name[:2]
        octave = int(note_name[2:])
    else:
        letter = note_name[0]
        octave = int(note_name[1:])
    semitone = NOTE_OFFSETS[letter]
    return semitone + (octave + 1) * 12

def midi_note_to_freq(note: int) -> int:
    return round(440 * 2 ** ((note - 69) / 12))

def write_entry(f, special, freq, delay):
    f.write(struct.pack("<BHI", special, freq, delay))

def parse_note(note_str: str) -> int:
    note_str = note_str.strip()
    if note_str.isdigit():  # decimal midi number
        return int(note_str)
    else:
        return note_name_to_midi(note_str)

def process_line(line, us_per_beat, speaker_on):
    """
    Parse a line of input and return (special, freq, delay, updated_speaker_on)
    """
    parts = line.strip().split()
    if not parts:
        return None, None, None, speaker_on

    if len(parts) == 3:
        prefix, note_str, beats = parts
        prefix = prefix.upper()
    elif len(parts) == 2:
        prefix, note_str, beats = None, parts[0], parts[1]
    else:
        raise ValueError("Invalid input line: " + line)

    beats = float(beats)
    delay = int(us_per_beat * beats)

    # --- REST (just delay, don’t touch speaker state) ---
    if note_str.lower() == "rest":
        return 4, 0, delay, speaker_on

    # --- OFF (turn off speaker for duration) ---
    if prefix == "OFF":
        # First turn speaker off immediately
        if speaker_on:
            return [(1, 0, 0), (4, 0, delay)], 0, 0, False
        else:
            return (4, 0, delay, False)  # already off, just delay


    # --- Parse actual note ---
    midi_note = parse_note(note_str)
    freq = midi_note_to_freq(midi_note)

    if prefix == "ON":
        return 2, freq, delay, True
    else:
        if not speaker_on:
            raise ValueError("Bare note given while speaker is off: " + line)
        return 0, freq, delay, speaker_on  # continue with speaker on

def main():
    print("NSPSMF Tracker with optional input file")
    bpm = float(input("Enter tempo (BPM): "))
    time_signature = input("Enter time signature (beats per measure, e.g. 4/4): ")
    beats_per_measure = int(time_signature.split("/")[0])
    us_per_beat = int(60_000_000 / bpm)

    input_file = input("Enter input file of notes (leave blank to enter manually): ").strip()
    out_file = input("Output file name (.spk): ")

    speaker_on = False
    entries = []

    if input_file:
        with open(input_file, "r") as f:
            lines = f.readlines()
    else:
        lines = []

    # Interactive input if no file or after file
    while True:
        if lines:
            line = lines.pop(0).strip()
        else:
            line = input("> ").strip()

        if line.lower() in ("end", "exit"):
            break

        try:
            special, freq, delay, speaker_on = process_line(line, us_per_beat, speaker_on)
            if special is not None:
                entries.append((special, freq, delay))
        except Exception as e:
            print("Error processing line:", e)
            if not lines:  # only prompt again if interactive
                continue

    # Ensure speaker off and end-of-song
    if speaker_on:
        entries.append((1, 0, 0))  # force off
    entries.append((3, 0, 0))      # end marker

    # Write SPK file
    with open(out_file, "wb") as f:
        for special, freq, delay in entries:
            write_entry(f, special, freq, delay)

    print("Done! Saved", out_file)

if __name__ == "__main__":
    main()
