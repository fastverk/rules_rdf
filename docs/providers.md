<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Providers for the four rules_rdf toolchain types.

Each provider wraps both the executable and the runfiles needed
to invoke it. Carrying runfiles in the provider matters for
plugin implementations that aren't a single self-contained binary
— py_binary, java_binary, sh_binary all stage helper files via
runfiles. Consuming rules merge the provider's `runfiles` into
their own to make the plugin actually executable inside a Bazel
sandbox.

<a id="RdfDatasetInfo"></a>

## RdfDatasetInfo

<pre>
load("@rules_rdf//rdf:providers.bzl", "RdfDatasetInfo")

RdfDatasetInfo(<a href="#RdfDatasetInfo-files">files</a>, <a href="#RdfDatasetInfo-in_format">in_format</a>)
</pre>

A declared RDF dataset.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="RdfDatasetInfo-files"></a>files |  depset[File]: source files in the dataset.    |
| <a id="RdfDatasetInfo-in_format"></a>in_format |  str: serialization of the dataset files. One of turtle, ntriples, nquads, trig, jsonld, rdfxml.    |


<a id="RdfReasonerToolchainInfo"></a>

## RdfReasonerToolchainInfo

<pre>
load("@rules_rdf//rdf:providers.bzl", "RdfReasonerToolchainInfo")

RdfReasonerToolchainInfo(<a href="#RdfReasonerToolchainInfo-binary">binary</a>, <a href="#RdfReasonerToolchainInfo-runfiles">runfiles</a>)
</pre>

An RDF inference engine. Resolved by `rdf_reason`.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="RdfReasonerToolchainInfo-binary"></a>binary |  File: an executable that runs RDFS / OWL / custom-rule inference and emits derived triples.    |
| <a id="RdfReasonerToolchainInfo-runfiles"></a>runfiles |  runfiles: the plugin binary's runfiles bundle.    |


<a id="RdfSerializerToolchainInfo"></a>

## RdfSerializerToolchainInfo

<pre>
load("@rules_rdf//rdf:providers.bzl", "RdfSerializerToolchainInfo")

RdfSerializerToolchainInfo(<a href="#RdfSerializerToolchainInfo-binary">binary</a>, <a href="#RdfSerializerToolchainInfo-runfiles">runfiles</a>)
</pre>

An RDF format converter. Resolved by `rdf_transform`.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="RdfSerializerToolchainInfo-binary"></a>binary |  File: an executable that converts between RDF serializations (Turtle / N-Triples / N-Quads / JSON-LD / RDF/XML / TriG).    |
| <a id="RdfSerializerToolchainInfo-runfiles"></a>runfiles |  runfiles: the plugin binary's runfiles bundle.    |


<a id="RdfValidatorToolchainInfo"></a>

## RdfValidatorToolchainInfo

<pre>
load("@rules_rdf//rdf:providers.bzl", "RdfValidatorToolchainInfo")

RdfValidatorToolchainInfo(<a href="#RdfValidatorToolchainInfo-binary">binary</a>, <a href="#RdfValidatorToolchainInfo-runfiles">runfiles</a>)
</pre>

An RDF validator (SHACL today; ShEx in scope for v0.2). Resolved by `rdf_validate_test`.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="RdfValidatorToolchainInfo-binary"></a>binary |  File: an executable that validates an RDF dataset against a shapes graph per the contract.    |
| <a id="RdfValidatorToolchainInfo-runfiles"></a>runfiles |  runfiles: the plugin binary's runfiles bundle.    |


<a id="SparqlEngineToolchainInfo"></a>

## SparqlEngineToolchainInfo

<pre>
load("@rules_rdf//rdf:providers.bzl", "SparqlEngineToolchainInfo")

SparqlEngineToolchainInfo(<a href="#SparqlEngineToolchainInfo-binary">binary</a>, <a href="#SparqlEngineToolchainInfo-runfiles">runfiles</a>)
</pre>

A SPARQL query engine. Resolved by `sparql_query_test` and `sparql_query_run`.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="SparqlEngineToolchainInfo-binary"></a>binary |  File: an executable that runs SPARQL queries per the rules_rdf plugin contract.    |
| <a id="SparqlEngineToolchainInfo-runfiles"></a>runfiles |  runfiles: the plugin binary's runfiles bundle.    |


