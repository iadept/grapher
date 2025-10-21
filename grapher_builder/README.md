# Grapher

Grapher is helper for generate GraphQL from dart code!

# Usage

See example project

Also see doc in annotation project

Add dependencies:
```yaml
dependencies:
    grapher_annotation:

dev_dependencies:
    grapher_builder:
```

Create or modify build.yaml (optional for validation with schema)
```yaml
targets:
  $default:
    builders:
      grapher_builder:
        options:
          schemaFolder: "./schema" # Path with graphqls files
```
##

