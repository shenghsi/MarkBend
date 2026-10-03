"""Read exported Return signposts and CPU samples. Do not run a GUI test."""
import argparse
import collections
import json
import statistics
import xml.etree.ElementTree as XML


def table(path):
    root = XML.parse(path).getroot()
    ids = {item.get("id"): item for item in root.iter() if item.get("id")}

    def resolve(item):
        while item.get("ref"):
            item = ids[item.get("ref")]
        return item

    columns = [item.findtext("mnemonic") for item in root.find(".//schema")]
    rows = [{key: resolve(value) for key, value in zip(columns, row)}
            for row in root.iter("row")]
    return rows, resolve


def report(signposts, samples):
    rows, _ = table(signposts)
    markers = collections.defaultdict(dict)
    processes = set()
    for row in rows:
        if row["subsystem"].text != "org.markbend.profile":
            continue
        sample = int(row["identifier"].text)
        processes.add(row["process"].findtext("pid"))
        name = row["name"].text
        key = row["event-type"].text if name == "Return" else name
        if key in markers[sample]:
            raise ValueError("Duplicate marker")
        markers[sample][key] = int(row["time"].text)
    keys = ["Begin", "ReturnExtracted", "SourceReplaceEntry", "End"]
    if sorted(markers) != list(range(1, 21)):
        raise ValueError("Expected 20 sample IDs")
    if len(processes) != 1 or None in processes:
        raise ValueError("Expected one marked process")
    for marker in markers.values():
        if list(marker) != keys or list(marker.values()) != sorted(marker.values()):
            raise ValueError("Incomplete or unordered markers")
    ordered = sorted(markers.values(), key=lambda marker: marker["Begin"])
    if any(left["End"] > right["Begin"] for left, right in zip(ordered, ordered[1:])):
        raise ValueError("Overlapping Return intervals")

    phases = [("input", keys[0], keys[1]), ("core", keys[1], keys[2]),
              ("presentation", keys[2], keys[3])]
    totals = collections.Counter()
    missing = collections.Counter()
    self_counts = collections.defaultdict(collections.Counter)
    inclusive = collections.defaultdict(collections.Counter)
    threads = collections.defaultdict(collections.Counter)
    callers = collections.Counter()
    caller_samples = collections.defaultdict(set)
    helper_counts = collections.defaultdict(collections.Counter)
    rows, resolve = table(samples)
    for row in rows:
        if row["process"].findtext("pid") not in processes:
            continue
        timestamp = int(row["time"].text)
        hit = next(((sample, phase) for sample, marker in markers.items()
                    for phase, start, end in phases
                    if marker[start] <= timestamp < marker[end]), None)
        if hit is None:
            continue
        sample, phase = hit
        weight = int(row["weight"].text) / 1_000_000
        totals[phase] += weight
        thread = row["thread"]
        tid = next(thread.iter("tid"), None)
        if tid is None:
            raise ValueError("Missing thread identity")
        thread_key = tid.text + " " + thread.get("fmt", "")
        threads[phase][thread_key] += weight
        stack = row["stack"] if "stack" in row else row["backtrace"]
        backtrace = next(stack.iter("backtrace"), None)
        if backtrace is None:
            missing[phase] += 1
            continue
        names = [resolve(frame).get("name", "?") for frame in backtrace]
        if not names:
            missing[phase] += 1
            continue
        self_counts[phase][names[0]] += weight
        for name in set(names):
            inclusive[phase][name] += weight
        if phase == "core" and names[0] in ("term_drop", "rfc_wrap", "span_fade"):
            caller = next((name for name in names[1:] if name.startswith("WL_FID_")),
                          "no_named_Bend_caller")
            callers[caller] += weight
            caller_samples[caller].add(sample)
            helper_counts[caller][names[0]] += weight
    return {
        "marker_sets": len(markers),
        "phases": {phase: {
            "median_wall_ms": statistics.median(
                (marker[end] - marker[start]) / 1_000_000 for marker in markers.values()),
            "cpu_sample_ms": totals[phase], "missing_stacks": missing[phase],
            "self_ms": self_counts[phase].most_common(),
            "inclusive_ms": inclusive[phase].most_common(),
            "thread_ms": threads[phase].most_common(),
        } for phase, start, end in phases},
        "core_helper_callers": [{"caller": caller, "self_helper_ms": weight,
                                 "sample_count": len(caller_samples[caller]),
                                 "helpers": dict(helper_counts[caller])}
                                for caller, weight in callers.most_common()],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("signposts")
    parser.add_argument("samples")
    args = parser.parse_args()
    print(json.dumps(report(args.signposts, args.samples), indent=2))
