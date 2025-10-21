class Buffer {
  final StringBuffer buffer;
  int indent;
  bool _isNewLine = true;

  Buffer() : buffer = StringBuffer(), indent = 0;

  Buffer._(this.buffer, this.indent);

  void write(String value) {
    _write(value);
  }

  void block(void Function(Buffer b) fn) {
    final b = Buffer._(buffer, indent + 1);
    fn(b);
  }

  void writeln([Object? value]) {
    if (value is Iterable) {
      for (final line in value) {
        if (line.toString().isEmpty) continue;
        _write('${line ?? ''}\n');
      }
      return;
    }
    _write('${value ?? ''}\n');
  }

  void _write(String value) {
    if (_isNewLine) {
      buffer.write('\t' * indent);
      _isNewLine = false;
    }
    buffer.write(value);
    if (value.endsWith('\n')) {
      _isNewLine = true;
    }
  }

  @override
  String toString() => buffer.toString();
}
