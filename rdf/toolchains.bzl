"""Toolchain registration rules for rules_rdf.

One rule per toolchain type. Each takes the plugin binary as a
mandatory exec-config label and exposes the matching `*ToolchainInfo`
provider with both the binary File and its runfiles bundle.

Concrete plugins (rules_jena, rules_rdflib, …) register via:

    sparql_engine_toolchain(
        name = "jena_arq_sparql_toolchain",
        binary = ":jena_sparql",
    )

    toolchain(
        name = "jena_arq_sparql",
        toolchain = ":jena_arq_sparql_toolchain",
        toolchain_type = "@rules_rdf//rdf:sparql_engine_toolchain_type",
    )
"""

load(":providers.bzl",
     "RdfReasonerToolchainInfo",
     "RdfSerializerToolchainInfo",
     "RdfValidatorToolchainInfo",
     "SparqlEngineToolchainInfo")

_BINARY_ATTRS = {
    "binary": attr.label(
        executable = True,
        cfg = "exec",
        mandatory = True,
        doc = "The plugin executable. Must conform to the contract " +
              "in [rdf/plugin_contract.md](plugin_contract.md).",
    ),
}

def _make_info(info_cls, ctx):
    """Bundle the binary + its runfiles into the requested info."""
    return info_cls(
        binary = ctx.executable.binary,
        runfiles = ctx.attr.binary[DefaultInfo].default_runfiles,
    )

def _sparql_engine_impl(ctx):
    return [platform_common.ToolchainInfo(
        sparql_engine_info = _make_info(SparqlEngineToolchainInfo, ctx),
    )]

sparql_engine_toolchain = rule(
    implementation = _sparql_engine_impl,
    attrs = _BINARY_ATTRS,
    doc = "Declare a SPARQL engine toolchain.",
)

def _rdf_validator_impl(ctx):
    return [platform_common.ToolchainInfo(
        rdf_validator_info = _make_info(RdfValidatorToolchainInfo, ctx),
    )]

rdf_validator_toolchain = rule(
    implementation = _rdf_validator_impl,
    attrs = _BINARY_ATTRS,
    doc = "Declare an RDF validator toolchain.",
)

def _rdf_serializer_impl(ctx):
    return [platform_common.ToolchainInfo(
        rdf_serializer_info = _make_info(RdfSerializerToolchainInfo, ctx),
    )]

rdf_serializer_toolchain = rule(
    implementation = _rdf_serializer_impl,
    attrs = _BINARY_ATTRS,
    doc = "Declare an RDF serializer (format-converter) toolchain.",
)

def _rdf_reasoner_impl(ctx):
    return [platform_common.ToolchainInfo(
        rdf_reasoner_info = _make_info(RdfReasonerToolchainInfo, ctx),
    )]

rdf_reasoner_toolchain = rule(
    implementation = _rdf_reasoner_impl,
    attrs = _BINARY_ATTRS,
    doc = "Declare an RDF reasoner (inference) toolchain.",
)
