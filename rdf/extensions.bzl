"""Bzlmod module extension for pinning RDF resources.

```starlark
rdf = use_extension("@rules_rdf//rdf:extensions.bzl", "rdf")
rdf.resource(
    name = "schemaorg_ttl",
    url = "https://schema.org/version/29.2/schemaorg-current-https.ttl",
    sha256 = "...",
    format = "turtle",
)
use_repo(rdf, "schemaorg_ttl")
# → @schemaorg_ttl//:dataset is an rdf_dataset ready for
#   rdf_transform / sparql_query / rdf_reason.
```
"""

load("//rdf:repositories.bzl", "rdf_resource_repository")

def _rdf_impl(mctx):
    for mod in mctx.modules:
        for r in mod.tags.resource:
            rdf_resource_repository(
                name = r.name,
                url = r.url,
                urls = r.urls,
                sha256 = r.sha256,
                format = r.format,
                out = r.out,
                allow_unverified = r.allow_unverified,
                build_file = r.build_file,
                build_file_content = r.build_file_content,
            )
    return mctx.extension_metadata(reproducible = True)

_resource = tag_class(
    attrs = {
        "name": attr.string(mandatory = True, doc = "Generated repo name (use_repo this)."),
        "url": attr.string(),
        "urls": attr.string_list(),
        "sha256": attr.string(default = ""),
        "format": attr.string(default = "turtle"),
        "out": attr.string(default = ""),
        "allow_unverified": attr.bool(default = False),
        "build_file": attr.label(allow_single_file = True),
        "build_file_content": attr.string(default = ""),
    },
)

rdf = module_extension(
    implementation = _rdf_impl,
    tag_classes = {"resource": _resource},
    doc = "Pin sha-verified RDF documents as rdf_dataset-bearing repos.",
)
