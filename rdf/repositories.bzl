"""`rdf_resource_repository` — hermetic, sha-pinned fetch of a single
RDF resource (TTL / JSON-LD / N-Triples / RDF-XML / …) into an
RDF-aware external repo.

The fetched repo overlays a BUILD that (a) `exports_files` the raw
artifact and (b) declares a ready-to-use `rdf_dataset(:dataset)` in the
resource's serialization — so downstream `rdf_transform` /
`sparql_query` / `rdf_reason` targets just depend on
`@<name>//:dataset`. This is the pin-an-ontology primitive that grounds
vendored vocabularies (schema.org, SKOS, DC, …) into the build graph.

RDF resources are single documents, not archives, so this `download`s
the file verbatim (no extraction). For multi-file bundles, fetch each
document as its own resource and combine via `rdf_dataset(srcs=[...])`.
"""

_DEFAULT_OVERLAY = """\
load("@rules_rdf//rdf:dataset.bzl", "rdf_dataset")

package(default_visibility = ["//visibility:public"])

exports_files(["{file}"])

# Ready-to-consume graph handle: `@{name}//:dataset`.
rdf_dataset(
    name = "dataset",
    srcs = ["{file}"],
    in_format = "{fmt}",
)
"""

def _rdf_resource_repo_impl(rctx):
    sha = rctx.attr.sha256
    if not sha and not rctx.attr.allow_unverified:
        fail("rules_rdf: rdf_resource_repository {name}: sha256 required (or set allow_unverified = True)".format(
            name = rctx.name,
        ))
    if not sha:
        # buildifier: disable=print
        print("rules_rdf: WARNING — downloading {name} unverified".format(name = rctx.name))

    urls = list(rctx.attr.urls)
    if rctx.attr.url:
        urls = [rctx.attr.url] + urls
    if not urls:
        fail("rules_rdf: rdf_resource_repository {name}: `url` or `urls` required.".format(
            name = rctx.name,
        ))

    out = rctx.attr.out if rctx.attr.out else urls[0].split("/")[-1]
    rctx.download(
        url = urls,
        sha256 = sha,
        output = out,
    )

    if rctx.attr.build_file_content and rctx.attr.build_file:
        fail("rules_rdf: {name}: pass exactly one of `build_file_content` or `build_file`.".format(name = rctx.name))
    if rctx.attr.build_file_content:
        rctx.file("BUILD.bazel", rctx.attr.build_file_content)
    elif rctx.attr.build_file:
        rctx.symlink(rctx.attr.build_file, "BUILD.bazel")
    else:
        rctx.file("BUILD.bazel", _DEFAULT_OVERLAY.format(
            file = out,
            fmt = rctx.attr.format,
            name = rctx.name,
        ))

rdf_resource_repository = repository_rule(
    implementation = _rdf_resource_repo_impl,
    attrs = {
        "url": attr.string(
            doc = "Primary download URL of the RDF document.",
        ),
        "urls": attr.string_list(
            doc = "Mirror URLs (tried after `url`). Either `url` or a " +
                  "non-empty `urls` is required.",
        ),
        "sha256": attr.string(
            default = "",
            doc = "sha256 of the document. Required unless allow_unverified.",
        ),
        "format": attr.string(
            default = "turtle",
            doc = "Serialization of the document (turtle / ntriples / " +
                  "nquads / trig / jsonld / rdfxml). Becomes the " +
                  "`rdf_dataset.in_format` in the default overlay.",
        ),
        "out": attr.string(
            default = "",
            doc = "Output filename. Defaults to the URL basename.",
        ),
        "allow_unverified": attr.bool(
            default = False,
            doc = "Skip the sha256 requirement; downgrade to a warning.",
        ),
        "build_file_content": attr.string(
            default = "",
            doc = "Override the default BUILD overlay (inline).",
        ),
        "build_file": attr.label(
            allow_single_file = True,
            doc = "Override the default BUILD overlay (label).",
        ),
    },
    doc = "Fetch a sha-pinned RDF document into an rdf_dataset-bearing repo.",
)
