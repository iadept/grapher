# Grapher

Grapher is a helper for generating client-side GraphQL from models written in Dart!

# Usage

See [example](https://github.com/iadept/grapher/tree/main/example) project

Also see [doc](https://github.com/iadept/grapher/tree/main/grapher_annotation) of annotation project

Add dependencies:
```yaml
dependencies:
    grapher_annotation: ^0.5.0

dev_dependencies:
    grapher_builder: ^0.5.0
```

Create or modify build.yaml (optional for validation with schema)
```yaml
targets:
  $default:
    builders:
      grapher_builder:
        options:
          schemaFolder: "./schema" # Path with graphQL files
          throwCriticalError: true # Exit from builder on critical error
```
