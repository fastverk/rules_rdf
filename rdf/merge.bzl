"""Blank-node-safe dataset merge.

A multi-file RDF dataset must be combined into a single graph by
*parsing each file independently and unioning* — never by byte-
concatenating the files. Concatenating, say, Turtle documents and
parsing the result as one document merges any blank-node labels
(`_:b0`, …) that two files happen to share, conflating distinct
subjects. The earlier `cat`-based path did exactly that.

`merged_dataset_input` instead runs the registered
`rdf_serializer_toolchain_type` engine with one `--input-file=PATH`
per dataset file. A conformant serializer (e.g. rules_jena's
`jena_riot`) parses each file independently — scoping each file's
blank nodes — and emits one canonical document. The result is a
correct RDF union, suitable to pipe to an operation plugin's stdin.

Consuming rules call this instead of cat-ing; that's how the
"good behavior" is enforced — there is no sanctioned path that
byte-concatenates a multi-file dataset.
"""

SERIALIZER_TOOLCHAIN = "@rules_rdf//rdf:rdf_serializer_toolchain_type"

def merged_dataset_input(ctx, dataset_info, out_name):
    """Return (file, runfiles) for the dataset as one merged graph.

    Single-file datasets pass through untouched (nothing to merge).
    Multi-file datasets are merged via the serializer toolchain.

    Requires the consuming rule to declare SERIALIZER_TOOLCHAIN in its
    `toolchains`.

    Args:
      ctx: the consuming rule's ctx.
      dataset_info: an RdfDatasetInfo.
      out_name: filename for the merged artifact.

    Returns:
      (File, runfiles) — the graph as a single file plus the runfiles
      needed to make it available to the test/action.
    """
    files = dataset_info.transitive_files.to_list()
    if len(files) == 1:
        return files[0], ctx.runfiles(files = files)

    serializer = ctx.toolchains[SERIALIZER_TOOLCHAIN].rdf_serializer_info
    merged = ctx.actions.declare_file(out_name)
    sorted_files = sorted(files, key = lambda f: f.short_path)
    input_flags = " ".join(['--input-file="%s"' % f.path for f in sorted_files])
    ctx.actions.run_shell(
        outputs = [merged],
        inputs = sorted_files,
        tools = [serializer.files_to_run],
        command = '"{bin}" --rule-name="{rn}" --in-format="{fmt}" --out-format="{fmt}" {inputs} > "{out}"'.format(
            bin = serializer.files_to_run.executable.path,
            rn = ctx.label.name + ".merge",
            fmt = dataset_info.in_format,
            inputs = input_flags,
            out = merged.path,
        ),
        mnemonic = "RdfMerge",
        progress_message = "merge %d RDF files (blank-node-safe) for %s" % (
            len(sorted_files),
            ctx.label,
        ),
    )
    return merged, ctx.runfiles(files = [merged])
