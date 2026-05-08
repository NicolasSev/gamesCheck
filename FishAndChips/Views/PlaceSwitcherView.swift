import SwiftUI

/// Menu picker to switch between the user's place memberships.
/// Shows inline if there's more than one place, otherwise just a label.
struct PlaceSwitcherView: View {
    @EnvironmentObject var placeSession: PlaceSessionManager

    var body: some View {
        if placeSession.memberships.isEmpty {
            EmptyView()
        } else if placeSession.memberships.count == 1 {
            Label(placeSession.activePlaceName ?? "—", systemImage: "mappin.circle.fill")
                .font(.subheadline)
                .foregroundColor(DS.Color.txt2)
        } else {
            Menu {
                ForEach(placeSession.memberships) { membership in
                    Button {
                        placeSession.setActivePlace(membership)
                    } label: {
                        HStack {
                            Text(membership.placeName)
                            if membership.isAdmin {
                                Text("admin").font(.caption).foregroundColor(.secondary)
                            }
                            if membership.placeId == placeSession.activePlaceId {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(DS.Color.green)
                    Text(placeSession.activePlaceName ?? "Выберите место")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DS.Color.txt)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(DS.Color.txt2)
                }
            }
        }
    }
}
