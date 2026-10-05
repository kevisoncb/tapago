import 'receipt_reader_stub.dart'
    if (dart.library.io) 'receipt_reader_io.dart' as impl;

Future<String?> readReceiptText(String path) => impl.readReceiptText(path);

Future<String?> readReceiptBytes(List<int> bytes) =>
    impl.readReceiptBytes(bytes);
