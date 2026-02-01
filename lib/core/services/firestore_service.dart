import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(FirebaseFirestore.instance);
});

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService(this._firestore);

  // Users Collection
  DocumentReference getUserDoc(String uid) => _firestore.collection('users').doc(uid);
  
  // History Sub-collection
  CollectionReference getUserHistoryCollection(String uid) => getUserDoc(uid).collection('history');
  
  // Favorites Sub-collection
  CollectionReference getUserFavoritesCollection(String uid) => getUserDoc(uid).collection('favorites');

  // Carts Root Collection (for sharing)
  CollectionReference getCartsCollection() => _firestore.collection('carts');

  // --- Batch Operations (for Migration) ---

  Future<void> batchWriteHistory(String uid, List<Map<String, dynamic>> historyItems) async {
    final batch = _firestore.batch();
    final collection = getUserHistoryCollection(uid);

    for (var item in historyItems) {
      // Use timestamp as ID or random ID, ensuring uniqueness
      final docRef = collection.doc(item['id'] ?? collection.doc().id); 
      batch.set(docRef, item, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> batchWriteFavorites(String uid, List<Map<String, dynamic>> favoriteItems) async {
    final batch = _firestore.batch();
    final collection = getUserFavoritesCollection(uid);

    for (var item in favoriteItems) {
      final docRef = collection.doc(item['id'] ?? collection.doc().id);
      batch.set(docRef, item, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> batchWriteCarts(String uid, List<Map<String, dynamic>> carts) async {
    final batch = _firestore.batch();
    final collection = getCartsCollection();

    for (var cart in carts) {
      // Ensure cart has ownerId
      cart['ownerId'] = uid;
      cart['members'] = [uid];
      
      final docRef = collection.doc(cart['id'] ?? collection.doc().id);
      batch.set(docRef, cart, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // --- Fetch Operations (for Restore) ---

  Future<List<Map<String, dynamic>>> fetchHistory(String uid) async {
    final snapshot = await getUserHistoryCollection(uid).get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> fetchFavorites(String uid) async {
    final snapshot = await getUserFavoritesCollection(uid).get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> fetchCarts(String uid) async {
    // Fetch carts where the user is a member
    final snapshot = await getCartsCollection()
        .where('members', arrayContains: uid)
        .get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }
}
