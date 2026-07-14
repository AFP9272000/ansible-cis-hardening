#!/usr/bin/env python3
"""Compare baseline and hardened OpenSCAP XCCDF results per host.

Pairs files named <host>-baseline.xml and <host>-hardened.xml in the given
results directory and emits a markdown delta: result counts before and after,
rules that flipped from fail to pass, and any regressions.

Usage:
    python3 scripts/compliance_delta.py scans/results -o scans/results/compliance-delta.md
"""

import argparse
import glob
import os
import sys
import xml.etree.ElementTree as ET
from collections import Counter

XCCDF_NAMESPACES = (
    "http://checklists.nist.gov/xccdf/1.2",
    "http://checklists.nist.gov/xccdf/1.1",
)
RULE_PREFIX = "xccdf_org.ssgproject.content_rule_"


def parse_results(path):
    """Return {rule_id: result} for every rule-result in an XCCDF result file."""
    results = {}
    for _event, elem in ET.iterparse(path):
        for ns in XCCDF_NAMESPACES:
            if elem.tag == f"{{{ns}}}rule-result":
                idref = elem.get("idref", "")
                result_elem = elem.find(f"{{{ns}}}result")
                if idref and result_elem is not None and result_elem.text:
                    results[idref] = result_elem.text.strip()
                elem.clear()
    return results


def short_id(rule_id):
    return rule_id.replace(RULE_PREFIX, "")


def find_pairs(results_dir):
    pairs = []
    for baseline in sorted(glob.glob(os.path.join(results_dir, "*-baseline.xml"))):
        hardened = baseline.replace("-baseline.xml", "-hardened.xml")
        if os.path.exists(hardened):
            host = os.path.basename(baseline)[: -len("-baseline.xml")]
            pairs.append((host, baseline, hardened))
    return pairs


def build_report(pairs):
    lines = ["# Compliance Delta", ""]
    lines.append(
        "Baseline and hardened OpenSCAP results compared per host. "
        "Counts cover every rule in the evaluated profile."
    )
    lines.append("")

    for host, baseline_path, hardened_path in pairs:
        baseline = parse_results(baseline_path)
        hardened = parse_results(hardened_path)
        base_counts = Counter(baseline.values())
        hard_counts = Counter(hardened.values())

        lines.append(f"## {host}")
        lines.append("")
        lines.append("| Result | Baseline | Hardened |")
        lines.append("| --- | --- | --- |")
        for key in sorted(set(base_counts) | set(hard_counts)):
            lines.append(f"| {key} | {base_counts.get(key, 0)} | {hard_counts.get(key, 0)} |")
        lines.append("")

        fixed = sorted(
            rule
            for rule, result in baseline.items()
            if result == "fail" and hardened.get(rule) == "pass"
        )
        regressed = sorted(
            rule
            for rule, result in hardened.items()
            if result == "fail" and baseline.get(rule) == "pass"
        )

        lines.append(f"**Newly passing rules ({len(fixed)}):**")
        lines.append("")
        if fixed:
            lines.extend(f"- {short_id(rule)}" for rule in fixed)
        else:
            lines.append("- none")
        lines.append("")

        if regressed:
            lines.append(f"**Regressions ({len(regressed)}):**")
            lines.append("")
            lines.extend(f"- {short_id(rule)}" for rule in regressed)
            lines.append("")

    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results_dir", help="Directory containing *-baseline.xml and *-hardened.xml")
    parser.add_argument("-o", "--output", help="Optional markdown output path")
    args = parser.parse_args()

    pairs = find_pairs(args.results_dir)
    if not pairs:
        sys.exit("No baseline/hardened result pairs found in " + args.results_dir)

    report = build_report(pairs)
    print(report)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(report)
        print(f"Wrote {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
