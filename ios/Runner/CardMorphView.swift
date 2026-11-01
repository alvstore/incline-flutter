//
//  CardMorphView.swift
//  Incline - Luxury Fitness Member App
//
//  60fps Card Morph to Screen Interaction (SwiftUI)
//  Implements matchedGeometryEffect, spring physics, and interactive drag-to-dismiss.
//

import SwiftUI

// MARK: - Model
struct TrackableProduct: Identifiable {
    let id: String
    let name: String
    let category: String
    let price: Int
    let iconName: String
    let description: String
    let vaultTemp: String
}

// MARK: - Main Container View
struct CardMorphView: View {
    @Namespace private var cardNamespace
    @State private var selectedProduct: TrackableProduct?
    @State private var dragOffset: CGSize = .zero

    let products: [TrackableProduct] = [
        TrackableProduct(
            id: "iso-01",
            name: "Isopure Zero Carb 100% Whey Protein Isolate",
            category: "PROTEIN & ISOLATE",
            price: 4999,
            iconName: "bolt.fill",
            description: "25g of 100% pure whey protein isolate per scoop. Zero sugar, zero carbs. Formulated for ultra-fast biological absorption and lean muscle synthesis.",
            vaultTemp: "Preserved at 18°C in Club Dispensary"
        ),
        TrackableProduct(
            id: "cre-02",
            name: "Creapure® Micronized German Creatine",
            category: "STRENGTH & POWER",
            price: 1799,
            iconName: "flame.fill",
            description: "99.9% pure Creapure creatine monohydrate synthesized in Germany. Clinically verified to maximize intracellular phosphocreatine resynthesis during high-intensity intervals.",
            vaultTemp: "Preserved at 18°C in Club Dispensary"
        ),
        TrackableProduct(
            id: "eaa-03",
            name: "Fermented Essential Amino Acids (EAA)",
            category: "AMINO & RECOVERY",
            price: 2499,
            iconName: "drop.fill",
            description: "Full-spectrum 9 essential amino acids with natural electrolyte matrix. Supports intra-workout hydration, reduces muscle soreness, and halts protein breakdown.",
            vaultTemp: "Preserved at 18°C in Club Dispensary"
        ),
        TrackableProduct(
            id: "col-04",
            name: "Cold-Brew High Altitude Single Origin",
            category: "CLEAN FUEL & SNACKS",
            price: 349,
            iconName: "cup.and.saucer.fill",
            description: "Slow-steeped for 18 hours using artisanal Ethiopian Yirgacheffe beans. Delivers clean caffeine elevation without cortisol spikes or acidity.",
            vaultTemp: "Chilled at 4°C in Concierge Vault"
        )
    ]

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.04, green: 0.04, blue: 0.05)
                .ignoresSafeArea()

            // Main Grid
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INCLINE DISPENSARY")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(2.0)
                            .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))

                        Text("Curated Fuel & Longevity")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // 2-Column Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 16) {
                        ForEach(products) { product in
                            if selectedProduct?.id != product.id {
                                ProductGridCard(
                                    product: product,
                                    namespace: cardNamespace,
                                    onTap: {
                                        withAnimation(.spring(response: 0.42, dampingFraction: 0.82, blendDuration: 0)) {
                                            selectedProduct = product
                                        }
                                    }
                                )
                            } else {
                                // Placeholder card to preserve grid spacing
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.04))
                                    .frame(height: 220)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 100)
            }

            // Expanded Full Card Detail Screen
            if let product = selectedProduct {
                ProductDetailScreenView(
                    product: product,
                    namespace: cardNamespace,
                    dragOffset: $dragOffset,
                    onDismiss: {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                            selectedProduct = nil
                            dragOffset = .zero
                        }
                    }
                )
                .transition(.identity)
                .zIndex(10)
            }
        }
    }
}

// MARK: - Product Grid Card (Source)
struct ProductGridCard: View {
    let product: TrackableProduct
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Full Card Hero Header
                ZStack(alignment: .topLeading) {
                    // Card Visual Container
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.13, green: 0.11, blue: 0.07), Color(red: 0.11, green: 0.11, blue: 0.13)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .matchedGeometryEffect(id: "card_bg_\(product.id)", in: namespace)
                        .frame(height: 120)

                    // Watermark / Luxury Badge
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color(red: 0.83, green: 0.69, blue: 0.22).opacity(0.12))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: product.iconName)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
                                )
                                .matchedGeometryEffect(id: "icon_\(product.id)", in: namespace)
                            Spacer()
                        }
                        Spacer()
                    }
                    .frame(height: 120)

                    // Category Pill
                    Text(product.category)
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(0.6)
                        .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(red: 0.83, green: 0.69, blue: 0.22).opacity(0.35), lineWidth: 0.8)
                        )
                        .padding(8)
                        .matchedGeometryEffect(id: "pill_\(product.id)", in: namespace)
                }

                // Card Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(height: 32, alignment: .topLeading)
                        .matchedGeometryEffect(id: "title_\(product.id)", in: namespace)

                    HStack {
                        Text("₹\(product.price)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
                            .matchedGeometryEffect(id: "price_\(product.id)", in: namespace)

                        Spacer()

                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
                    }
                }
                .padding(10)
                .background(Color(red: 0.11, green: 0.11, blue: 0.13))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Product Detail Screen (Destination with Hero Header)
struct ProductDetailScreenView: View {
    let product: TrackableProduct
    let namespace: Namespace.ID
    @Binding var dragOffset: CGSize
    let onDismiss: () -> Void

    @State private var appearContent: Bool = false
    @State private var selectedFulfillment: String = "concierge"

    var body: some View {
        ZStack(alignment: .top) {
            // Dark Backdrop
            Color.black
                .opacity(appearContent ? 0.95 : 0.0)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Morphing Screen Container
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // FULL CARD HERO HEADER
                    ZStack(alignment: .bottomLeading) {
                        // Morphing Background & Visual
                        RoundedRectangle(cornerRadius: appearContent ? 32 : 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.14, green: 0.12, blue: 0.07), Color(red: 0.09, green: 0.09, blue: 0.11)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .matchedGeometryEffect(id: "card_bg_\(product.id)", in: namespace)
                            .frame(height: 360)

                        // Center Icon Visual
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color(red: 0.83, green: 0.69, blue: 0.22).opacity(0.14))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: product.iconName)
                                            .font(.system(size: 44, weight: .bold))
                                            .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
                                    )
                                    .matchedGeometryEffect(id: "icon_\(product.id)", in: namespace)
                                Spacer()
                            }
                            Spacer()
                        }
                        .frame(height: 360)

                        // Bottom Ambient Shadow & Pills
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(product.category)
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(0.8)
                                    .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(red: 0.83, green: 0.69, blue: 0.22).opacity(0.4), lineWidth: 1)
                                    )
                                    .matchedGeometryEffect(id: "pill_\(product.id)", in: namespace)

                                Spacer()

                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(Color(red: 0.06, green: 0.72, blue: 0.51))
                                        .font(.system(size: 12))
                                    Text("100% Incline Certified")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(red: 0.06, green: 0.72, blue: 0.51))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color(red: 0.06, green: 0.72, blue: 0.51).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(20)
                    }

                    // STAGGERED REVEAL CONTENT BODY
                    VStack(alignment: .leading, spacing: 20) {
                        // Title & Price
                        VStack(alignment: .leading, spacing: 8) {
                            Text(product.name)
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .matchedGeometryEffect(id: "title_\(product.id)", in: namespace)

                            HStack {
                                Text("₹\(product.price)")
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                    .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
                                    .matchedGeometryEffect(id: "price_\(product.id)", in: namespace)

                                Text("incl. 18% GST")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)

                                Spacer()
                            }
                        }

                        // Description
                        Text(product.description)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(white: 0.75))
                            .lineSpacing(4)

                        // Dispensary Vault Bento Box
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.83, green: 0.69, blue: 0.22).opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "snowflake")
                                    .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cold-Chain Vault Storage")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text(product.vaultTemp)
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )

                        // Collection Preference
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FULFILLMENT PREFERENCE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(.gray)

                            HStack(spacing: 12) {
                                FulfillmentButton(
                                    title: "Front Desk Pickup",
                                    icon: "storefront.fill",
                                    isSelected: selectedFulfillment == "concierge",
                                    onTap: { selectedFulfillment = "concierge" }
                                )

                                FulfillmentButton(
                                    title: "Private Locker #42",
                                    icon: "lock.fill",
                                    isSelected: selectedFulfillment == "locker",
                                    onTap: { selectedFulfillment = "locker" }
                                )
                            }
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(20)
                    .opacity(appearContent ? 1.0 : 0.0)
                    .offset(y: appearContent ? 0 : 20)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: appearContent ? 32 : 16))
            .scaleEffect(max(0.85, 1.0 - (dragOffset.height / 1000.0)))
            .offset(y: max(0, dragOffset.height))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 120 || value.velocity.height > 800 {
                            onDismiss()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragOffset = .zero
                            }
                        }
                    }
            )

            // FLOATING GLASSMORPHIC TOP CONTROLS
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 54)
            .opacity(appearContent ? 1.0 : 0.0)

            // STICKY BOTTOM ACTION BAR
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        onDismiss()
                    }) {
                        HStack {
                            Image(systemName: "bag.badge.plus")
                            Text("Add to Bag")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(red: 0.83, green: 0.69, blue: 0.22), lineWidth: 1.5)
                        )
                    }

                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                        impact.impactOccurred()
                        onDismiss()
                    }) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Instant Checkout")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(red: 0.83, green: 0.69, blue: 0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.white.opacity(0.1)),
                    alignment: .top
                )
            }
            .ignoresSafeArea(edges: .bottom)
            .opacity(appearContent ? 1.0 : 0.0)
            .offset(y: appearContent ? 0 : 40)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.25).delay(0.12)) {
                appearContent = true
            }
        }
    }
}

// MARK: - Fulfillment Selector Button
struct FulfillmentButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? Color(red: 0.83, green: 0.69, blue: 0.22) : .gray)

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color(red: 0.83, green: 0.69, blue: 0.22) : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color(red: 0.83, green: 0.69, blue: 0.22).opacity(0.12) : Color(red: 0.11, green: 0.11, blue: 0.13))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(red: 0.83, green: 0.69, blue: 0.22) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    CardMorphView()
        .preferredColorScheme(.dark)
}
