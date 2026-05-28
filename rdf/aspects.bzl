"""`rdf_namespace_aspect` — traverse an `rdf_dataset`'s `deps` graph and
extract, per node, the namespaces it declares + the ontologies it
`owl:imports`. Propagating this as an aspect (rather than baking it into
`rdf_dataset`) means the analysis attaches to *any* dataset target
without wrapping it, and runs one extraction action per graph in the
closure.

Consumed by `rdf_namespace_manifest` (in `:namespace.bzl`) to (a) harvest
the merged namespace set of a grounding ontology — the vocabulary the
parser's SFT must target — and (b) gate import-completeness: every
`owl:imports` IRI must be provided by some pinned dataset in the closure.
"""

load("//rdf:providers.bzl", "RdfDatasetInfo")

RdfNamespaceInfo = provider(
    doc = "Per-dataset namespace/import extraction, accumulated over deps.",
    fields = {
        "direct": "File: this dataset's `.ns.json` (ontology/prefixes/imports).",
        "transitive": "depset[File]: `.ns.json` for the whole deps closure.",
    },
)

def _rdf_namespace_aspect_impl(target, ctx):
    if RdfDatasetInfo not in target:
        return []
    # The node's own files — read from the provider, not a rule attr, so
    # this works for any RdfDatasetInfo producer (rdf_dataset's `srcs`,
    # but also rdf_transform / rdf_reason outputs reached through `deps`).
    own = target[RdfDatasetInfo].files.to_list()
    out = ctx.actions.declare_file(target.label.name + ".ns.json")
    ctx.actions.run(
        executable = ctx.executable._tool,
        arguments = ["extract", "--out", out.path] + [f.path for f in own],
        inputs = own,
        outputs = [out],
        mnemonic = "RdfExtractNs",
        progress_message = "rdf namespaces %s" % target.label,
    )
    dep_closures = [
        d[RdfNamespaceInfo].transitive
        for d in getattr(ctx.rule.attr, "deps", [])
        if RdfNamespaceInfo in d
    ]
    return [RdfNamespaceInfo(
        direct = out,
        transitive = depset([out], transitive = dep_closures),
    )]

rdf_namespace_aspect = aspect(
    implementation = _rdf_namespace_aspect_impl,
    attr_aspects = ["deps"],
    attrs = {
        "_tool": attr.label(
            default = Label("//rdf:ns_tool"),
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Extract + propagate namespaces/imports over an rdf_dataset deps graph.",
)
