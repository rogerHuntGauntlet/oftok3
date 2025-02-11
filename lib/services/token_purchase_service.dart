import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './user_service.dart';

class TokenPurchaseService {
  static const String _tokens500Id = 'tokens_500';
  static const String _tokens1000Id = 'tokens_1000';
  static const String _tokens2500Id = 'tokens_2500';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<ProductDetails>> get products async* {
    if (!await _inAppPurchase.isAvailable()) {
      yield [];
      return;
    }

    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({
      _tokens500Id,
      _tokens1000Id,
      _tokens2500Id,
    });

    if (response.error != null) {
      print('Error loading products: ${response.error}');
      yield [];
      return;
    }

    yield response.productDetails;
  }

  Future<void> buyTokens(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    try {
      final bool success = await _inAppPurchase.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: true,
      );
      print('Purchase initiated: $success');
    } catch (e) {
      print('Error initiating purchase: $e');
      rethrow;
    }
  }

  Stream<List<PurchaseDetails>> get purchaseUpdates {
    return _inAppPurchase.purchaseStream;
  }

  Future<void> handlePurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.status == PurchaseStatus.purchased) {
      // Verify the purchase on the server side
      try {
        final userId = _auth.currentUser?.uid;
        if (userId == null) throw Exception('User not authenticated');

        // Get token amount from product ID
        int tokenAmount = _getTokenAmount(purchaseDetails.productID);

        // Get current user tokens
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final currentTokens = userDoc.data()?['tokens'] as int? ?? 0;
        final newTokenCount = currentTokens + tokenAmount;

        // Update user's tokens in Firestore
        await _userService.updateUserTokens(userId, newTokenCount);

        // Store purchase record
        await _firestore.collection('purchases').add({
          'userId': userId,
          'productId': purchaseDetails.productID,
          'purchaseTime': FieldValue.serverTimestamp(),
          'tokenAmount': tokenAmount,
          'verificationData': purchaseDetails.verificationData.serverVerificationData,
          'transactionId': purchaseDetails.purchaseID,
          'platform': defaultTargetPlatform.toString(),
        });

      } catch (e) {
        print('Error processing purchase: $e');
        rethrow;
      }
    }
  }

  int _getTokenAmount(String productId) {
    switch (productId) {
      case _tokens500Id:
        return 500;
      case _tokens1000Id:
        return 1000;
      case _tokens2500Id:
        return 2500;
      default:
        return 0;
    }
  }

  void dispose() {
    _inAppPurchase.purchaseStream.drain();
  }
} 