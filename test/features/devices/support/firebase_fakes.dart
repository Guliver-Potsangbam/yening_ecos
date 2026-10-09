// SDK stand-ins are restricted to tests; production uses the real SDK types.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestUser implements User {
  TestUser(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAuth implements FirebaseAuth {
  final changes = StreamController<User?>.broadcast();
  @override
  User? currentUser;
  @override
  Stream<User?> authStateChanges() => changes.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestFirestore implements FirebaseFirestore {
  final records = <String, Map<String, dynamic>>{};
  final queries = <String>[];
  final updates = <String>[];
  final writes = <String>[];
  final reads = <String>[];
  final feeds =
      <String, StreamController<QuerySnapshot<Map<String, dynamic>>>>{};

  StreamController<QuerySnapshot<Map<String, dynamic>>> feed(String uid) =>
      feeds.putIfAbsent(uid, () => StreamController.broadcast());

  void emit(String uid, Map<String, Map<String, dynamic>> documents) {
    feed(uid).add(TestQuerySnapshot(documents));
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      TestCollection(this, path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => transactionHandler(TestTransaction(this));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestCollection implements CollectionReference<Map<String, dynamic>> {
  TestCollection(this.store, this.path);
  final TestFirestore store;
  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      TestDocument(store, '$path/$id');

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      if (path != 'devices' ||
          invocation.positionalArguments.single != 'claimedByUid') {
        throw StateError('Device queries must constrain registry ownership.');
      }
      final uid = invocation.namedArguments[#isEqualTo] as String;
      store.queries.add(uid);
      return TestQuery(store, uid);
    }
    return super.noSuchMethod(invocation);
  }
}

class TestDocument implements DocumentReference<Map<String, dynamic>> {
  TestDocument(this.store, this.path);
  final TestFirestore store;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    store.reads.add(path);
    return TestDocumentSnapshot(store.records[path]);
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      TestCollection(store, '$path/$name');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestQuery implements Query<Map<String, dynamic>> {
  TestQuery(this.store, this.uid);
  final TestFirestore store;
  final String uid;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => store.feed(uid).stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  TestQuerySnapshot(Map<String, Map<String, dynamic>> records)
    : docs = records.entries
          .map((entry) => TestSnapshot(entry.key, entry.value))
          .toList();
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestSnapshot implements QueryDocumentSnapshot<Map<String, dynamic>> {
  TestSnapshot(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestDocumentSnapshot<T> implements DocumentSnapshot<T> {
  TestDocumentSnapshot(this.value);
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestTransaction implements Transaction {
  TestTransaction(this.store);
  final TestFirestore store;
  var hasWritten = false;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    if (hasWritten) throw StateError('Transaction reads must precede writes.');
    store.reads.add(reference.path);
    return TestDocumentSnapshot<T>(store.records[reference.path] as T?);
  }

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    hasWritten = true;
    store.updates.add(reference.path);
    store.records[reference.path]!.addAll(data.cast<String, dynamic>());
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    hasWritten = true;
    store.writes.add(reference.path);
    store.records[reference.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
