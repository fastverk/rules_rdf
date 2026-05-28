#!/usr/bin/env python3
"""Namespace / import-closure tool for the rdf_namespace_aspect.

Two modes:

  extract --out O FILE...   Parse each Turtle/N-Triples FILE and emit a
                            per-dataset JSON {ontology, prefixes, imports}:
                              * ontology — the IRI of the `owl:Ontology`
                                subject this graph *defines* (its provided
                                namespace), or "" if none.
                              * prefixes — {prefix: namespace-IRI} declared.
                              * imports  — IRIs named by `owl:imports`.

  merge --out O [--strict] NSJSON...
                            Fold the per-dataset JSONs of a deps closure
                            into a manifest:
                              * provided   — every defined ontology IRI.
                              * prefixes   — union of declared namespaces.
                              * imports    — union of owl:imports.
                              * missing    — imports with no provider in
                                             the closure.
                            With --strict, exit 1 if `missing` is non-empty
                            (import-completeness gate).

Parsing is a pragmatic scan sufficient for well-formed ontology
documents (prefix decls, the ontology header, owl:imports); it is not a
full RDF parser. A Jena-backed exact extractor is a future upgrade.
"""

import argparse
import json
import re
import sys

OWL_ONTOLOGY = "http://www.w3.org/2002/07/owl#Ontology"
OWL_IMPORTS = "http://www.w3.org/2002/07/owl#imports"
RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

_PREFIX = re.compile(r'@prefix\s+([\w.-]*):\s*<([^>]*)>\s*\.', re.I)
_SPARQL_PREFIX = re.compile(r'^\s*PREFIX\s+([\w.-]*):\s*<([^>]*)>', re.I | re.M)
_BASE = re.compile(r'@base\s*<([^>]*)>\s*\.', re.I)
_IRI = re.compile(r'<([^>]*)>')


def _prefixes(text):
    pm = {}
    for m in _PREFIX.finditer(text):
        pm[m.group(1)] = m.group(2)
    for m in _SPARQL_PREFIX.finditer(text):
        pm[m.group(1)] = m.group(2)
    return pm


def _resolve(term, pm, base):
    """Resolve a Turtle term (<IRI> or prefix:local or :local) to an IRI."""
    term = term.strip().rstrip(".,;")
    if term.startswith("<") and term.endswith(">"):
        return term[1:-1]
    if ":" in term:
        pfx, _, local = term.partition(":")
        if pfx in pm:
            return pm[pfx] + local
    return None


def extract(paths):
    ontology = ""
    prefixes = {}
    imports = []
    for path in paths:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
        pm = _prefixes(text)
        prefixes.update(pm)
        base_m = _BASE.search(text)
        base = base_m.group(1) if base_m else ""

        # owl:imports — match both the prefixed `owl:imports TERM` and the
        # full-IRI N-Triples `<...owl#imports> TERM` forms.
        # Capture the import target as either a full <IRI> (which may
        # contain dots) or a whitespace-delimited prefixed name.
        for m in re.finditer(r'owl:imports\s+(<[^>]+>|[^\s]+)', text):
            iri = _resolve(m.group(1), pm, base)
            if iri:
                imports.append(iri)
        for m in re.finditer(re.escape("<" + OWL_IMPORTS + ">") + r'\s+(<[^>]+>|[^\s]+)', text):
            iri = _resolve(m.group(1), pm, base)
            if iri:
                imports.append(iri)

        # ontology subject: `SUBJ a owl:Ontology` / `SUBJ rdf:type owl:Ontology`
        # / N-Triples full-IRI form.
        if not ontology:
            ont_pat = re.compile(
                r'([^\s]+)\s+(?:a|rdf:type|<' + re.escape(RDF_TYPE) + r'>)\s+'
                r'(?:owl:Ontology|<' + re.escape(OWL_ONTOLOGY) + r'>)'
            )
            m = ont_pat.search(text)
            if m:
                subj = m.group(1).strip()
                if subj == "<>" and base:
                    ontology = base
                else:
                    iri = _resolve(subj, pm, base)
                    if iri:
                        ontology = iri

    # dedup imports, keep order
    seen = set()
    uniq = []
    for i in imports:
        if i not in seen:
            seen.add(i)
            uniq.append(i)
    return {"ontology": ontology, "prefixes": prefixes, "imports": uniq}


def merge(ns_paths, strict):
    provided = set()
    prefixes = {}
    imports = []
    for p in ns_paths:
        with open(p) as f:
            d = json.load(f)
        if d.get("ontology"):
            provided.add(d["ontology"])
        prefixes.update(d.get("prefixes", {}))
        for i in d.get("imports", []):
            if i not in imports:
                imports.append(i)
    missing = sorted(i for i in imports if i not in provided)
    manifest = {
        "provided": sorted(provided),
        "prefixes": prefixes,
        "imports": sorted(imports),
        "missing": missing,
    }
    if strict and missing:
        sys.stderr.write(
            "rdf import-closure incomplete — unprovided imports:\n  "
            + "\n  ".join(missing) + "\n"
        )
        return manifest, 1
    return manifest, 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    pe = sub.add_parser("extract")
    pe.add_argument("--out", required=True)
    pe.add_argument("files", nargs="+")
    pm = sub.add_parser("merge")
    pm.add_argument("--out", required=True)
    pm.add_argument("--strict", action="store_true")
    pm.add_argument("files", nargs="*")
    args = ap.parse_args()

    if args.cmd == "extract":
        out = extract(args.files)
        with open(args.out, "w") as f:
            json.dump(out, f, indent=1, sort_keys=True)
        return 0
    else:
        manifest, code = merge(args.files, args.strict)
        with open(args.out, "w") as f:
            json.dump(manifest, f, indent=1, sort_keys=True)
        return code


if __name__ == "__main__":
    sys.exit(main())
