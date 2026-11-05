plugins { id("com.android.asset-pack") }
assetPack {
    packName = "festival_art"
    dynamicDelivery { deliveryType = "install-time" }
}
