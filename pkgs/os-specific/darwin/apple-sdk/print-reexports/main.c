#include <stdio.h>
#include <yaml.h>

static yaml_node_t *get_mapping_entry(yaml_document_t *document, yaml_node_t *mapping, const char *name) {
  if (!mapping) {
    fprintf(stderr, "get_mapping_entry: mapping is null\n");
    return NULL;
  }

  for (
      yaml_node_pair_t *pair = mapping->data.mapping.pairs.start; 
      pair < mapping->data.mapping.pairs.top;
      ++pair
  ) {
    yaml_node_t *key = yaml_document_get_node(document, pair->key);

    if (!key) {
      fprintf(stderr, "get_mapping_entry: key (%i) is null\n", pair->key);
      return NULL;
    }

    if (key->type != YAML_SCALAR_NODE) {
      fprintf(stderr, "get_mapping_entry: key is not a scalar\n");
      return NULL;
    }

    if (strncmp(key->data.scalar.value, name, key->data.scalar.length) != 0) {
      continue;
    }

    return yaml_document_get_node(document, pair->value);
  }

  return NULL;
}

static int emit_reexports(yaml_document_t *document) {
  yaml_node_t *root = yaml_document_get_root_node(document);

  yaml_node_t *exports = get_mapping_entry(document, root, "exports");

  if (!exports) {
    fprintf(stderr, "emit_reexports: no exports found\n");
    return 0;
  }

  if (exports->type != YAML_SEQUENCE_NODE) {
    fprintf(stderr, "emit_reexports, value is not a sequence\n");
    return 0;
  }

  for (
      yaml_node_item_t *export = exports->data.sequence.items.start;
      export < exports->data.sequence.items.top;
      ++export
  ) {
    yaml_node_t *export_node = yaml_document_get_node(document, *export);

    yaml_node_t *reexports = get_mapping_entry(document, export_node, "re-exports");

    if (!reexports) {
      continue;
    }

    for (
        yaml_node_item_t *reexport = reexports->data.sequence.items.start;
        reexport < reexports->data.sequence.items.top;
        ++reexport
    ) {
      yaml_node_t *val = yaml_document_get_node(document, *reexport);

      if (val->type != YAML_SCALAR_NODE) {
        fprintf(stderr, "item is not a scalar\n");
        return 0;
      }

      fwrite(val->data.scalar.value, val->data.scalar.length, 1, stdout);
      putchar('\n');
    }
  }

  return 1;
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "Invalid usage\n");
    goto err_exit;
  }

  FILE *f = fopen(argv[1], "r");
  if (!f) {
    perror("opening input file");
    goto err_exit;
  }

  yaml_parser_t yaml_parser;
  if (!yaml_parser_initialize(&yaml_parser)) {
    fprintf(stderr, "Failed to initialize yaml parser\n");
    goto err_file;
  }

  yaml_parser_set_input_file(&yaml_parser, f);
  
  yaml_document_t yaml_document;

  if(!yaml_parser_load(&yaml_parser, &yaml_document)) {
    fprintf(stderr, "Failed to load yaml file\n");
    goto err_yaml;
  }
  
  emit_reexports(&yaml_document);

  return 0;

err_yaml:
  yaml_parser_delete(&yaml_parser);

err_file:
  fclose(f);

err_exit:
  return 1;
}
