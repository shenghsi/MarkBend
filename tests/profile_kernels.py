"""Summarize exported CPU samples inside the two diagnostic kernel intervals."""
import argparse
import collections
import json
import statistics
from profile_return import table


def report(signposts, samples):
    rows, _ = table(signposts)
    marks = collections.defaultdict(dict)
    processes = set()
    for row in rows:
        if row["subsystem"].text != "org.markbend.kernel":
            continue
        name = row["name"].text
        if name not in ("DocumentKernel", "SceneKernel"):
            raise ValueError("Unknown kernel marker")
        key = (name, int(row["identifier"].text))
        event = row["event-type"].text
        if event not in ("Begin", "End") or event in marks[key]:
            raise ValueError("Invalid or duplicate marker")
        marks[key][event] = int(row["time"].text)
        processes.add(row["process"].findtext("pid"))
    expected = {("DocumentKernel", sample + 1) for sample in range(1, 21)}
    expected |= {("SceneKernel", sample + 33) for sample in range(1, 21)}
    if set(marks) != expected or len(processes) != 1 or None in processes:
        raise ValueError("Expected 20 intervals per kernel from one process")
    for marker in marks.values():
        if list(marker) != ["Begin", "End"] or marker["Begin"] >= marker["End"]:
            raise ValueError("Incomplete or unordered interval")
    ordered = sorted(marks.items(), key=lambda item: item[1]["Begin"])
    if any(left[1]["End"] > right[1]["Begin"] for left, right in zip(ordered, ordered[1:])):
        raise ValueError("Overlapping kernel intervals")
    if [key for key, _ in ordered] != sorted(expected):
        raise ValueError("Unexpected kernel sample order")

    totals = collections.Counter()
    missing = collections.Counter()
    self_counts = collections.defaultdict(collections.Counter)
    inclusive = collections.defaultdict(collections.Counter)
    threads = collections.defaultdict(collections.Counter)
    callers = collections.defaultdict(collections.Counter)
    seen = collections.defaultdict(set)
    rows, resolve = table(samples)
    for row in rows:
        if row["process"].findtext("pid") not in processes:
            continue
        timestamp = int(row["time"].text)
        key = next((key for key, marker in ordered
                    if marker["Begin"] <= timestamp < marker["End"]), None)
        if key is None:
            continue
        name, sample = key
        weight = int(row["weight"].text) / 1_000_000
        totals[name] += weight
        thread = row["thread"]
        tid = next(thread.iter("tid"), None)
        if tid is None:
            raise ValueError("Missing thread identity")
        threads[name][tid.text + " " + thread.get("fmt", "")] += weight
        backtrace = next(row["stack"].iter("backtrace"), None)
        if backtrace is None:
            missing[name] += 1
            continue
        frames = [resolve(frame).get("name", "?") for frame in backtrace]
        if not frames:
            missing[name] += 1
            continue
        self_counts[name][frames[0]] += weight
        for frame in set(frames):
            inclusive[name][frame] += weight
        if frames[0] in ("term_drop", "rfc_wrap", "span_fade"):
            caller = next((frame for frame in frames[1:] if frame.startswith("WL_FID_")),
                          "no_named_Bend_caller")
            callers[name][caller] += weight
            seen[(name, caller)].add(sample)
    return {name: {
        "interval_count": 20,
        "median_wall_ms": statistics.median((marker["End"] - marker["Begin"]) / 1_000_000
                                            for key, marker in ordered if key[0] == name),
        "cpu_sample_ms": totals[name], "missing_stacks": missing[name],
        "self_ms": self_counts[name].most_common(),
        "inclusive_ms": inclusive[name].most_common(),
        "thread_ms": threads[name].most_common(),
        "helper_callers": [{"caller": caller, "self_helper_ms": weight,
                            "sample_count": len(seen[(name, caller)])}
                           for caller, weight in callers[name].most_common()],
    } for name in ("DocumentKernel", "SceneKernel")}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("signposts")
    parser.add_argument("samples")
    args = parser.parse_args()
    print(json.dumps(report(args.signposts, args.samples), indent=2))
