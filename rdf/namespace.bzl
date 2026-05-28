"""`rdf_namespace_manifest` — fold the `rdf_namespace_aspect`'s per-node
extraction over a dataset's deps closure into one manifest:

  * `provided`  — every defined `owl:Ontology` IRI in the closure.
  * `prefixes`  — union of declared namespaces (the harvested grounding
                  vocabulary — feeds the parser's SFT target set).
  * `imports`   — union of `owl:imports`.
  * `missing`   — imports with no provider in the closure.

With `strict = True`, the merge fails the build when `missing` is
non-empty — an import-completeness gate for a grounding ontology
(every linked ontology must be pinned in the closure).
"""

load("//rdf:aspects.bzl", "RdfNamespaceInfo", "rdf_namespace_aspect")
load("//rdf:providers.bzl", "RdfDatasetInfo")

def _rdf_namespace_manifest_impl(ctx):
    ns_files = ctx.attr.dataset[RdfNamespaceInfo].transitive.to_list()
    out = ctx.actions.declare_file(ctx.label.name + ".manifest.json")
    args = ["merge", "--out", out.path]
    if ctx.attr.strict:
        args.append("--strict")
    args += [f.path for f in ns_files]
    ctx.actions.run(
        executable = ctx.executable._tool,
        arguments = args,
        inputs = ns_files,
        outputs = [out],
        mnemonic = "RdfNsManifest",
        progress_message = "rdf namespace manifest %s" % ctx.label,
    )
    return [DefaultInfo(files = depset([out]))]

rdf_namespace_manifest = rule(
    implementation = _rdf_namespace_manifest_impl,
    attrs = {
        "dataset": attr.label(
            aspects = [rdf_namespace_aspect],
            providers = [RdfDatasetInfo],
            mandatory = True,
            doc = "Root rdf_dataset; the manifest covers its deps closure.",
        ),
        "strict": attr.bool(
            default = False,
            doc = "Fail the build if any `owl:imports` is unprovided in " +
                  "the closure (import-completeness gate).",
        ),
        "_tool": attr.label(
            default = Label("//rdf:ns_tool"),
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Harvest namespaces + check import-completeness over a deps closure.",
)
