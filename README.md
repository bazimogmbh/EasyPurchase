# EasyPurchase Framework

EasyPurchase is a Swift package that simplifies the implementation of purchase logic and analytics for your iOS applications. It provides a set of public properties and functions to manage subscriptions, lifetime offers, the purchase process, and also collects and sends analytics data about user purchases. With EasyPurchase, you can seamlessly integrate in-app purchase functionality and gain valuable insights into user behavior.

## Features

- `isSubscribed` (Bool): A published property that indicates whether the user is currently subscribed.
- `isLifetimeSubscription` (Bool): A published property that indicates whether the user has a lifetime subscription.
- `offers` ([Offer]): A published array of available offers.

### Public Functions

- `configure(appstoreId: String, secretKey: String, lifetimeProductId: String?, defaultOfferId: String, offerIds: [String], allProductIds: [String])`: Configure EasyPurchase with the necessary parameters, including the App Store ID, secret key, product identifiers, and other settings.
- `restorePurchase(completion: @escaping (_ success: Bool, _ message: String) -> Void)`: Restore a previous purchase, if any, and call the provided completion handler with the results.
- `purchase(_ offer: Offer, completion: @escaping (_ success: Bool, _ message: String) -> Void)`: Initiate a purchase for a specific offer and handle the result through the completion handler.
- `purchase(_ productId: String, completion: @escaping (_ success: Bool, _ message: String) -> Void)`: Initiate a purchase for a specific product by its identifier and handle the result through the completion handler.

## Getting Started

1. Add EasyPurchase as a Swift package dependency in your Xcode project.
2. Import the EasyPurchase framework into your code.
3. Configure EasyPurchase with the necessary parameters using the `configure` function, including your App Store ID, secret key, and other relevant settings.
4. Use the provided properties and functions to manage purchase logic in your app.

## Example Usage

```swift
import EasyPurchase

// Configure EasyPurchase
EasyPurchase.shared.configure(
    appstoreId: "yourAppStoreID",
    secretKey: "yourSecretKey",
    lifetimeProductId: "yourLifetimeProductId",
    defaultOfferId: "product Id of project tha will be selected by defaults",
    offerIds: [Array of product IDs you want to show in an offer to the user],
    allProductIds: [Array of all product IDs that give a subscription to the user]
)

```

## Contact
If you have any questions, issues, or suggestions regarding EasyPurchase, please create an issue on GitHub or contact us at jenya.korsun@gmail.com.
