//
//  NotificationsView.swift
//  FishAndChips
//

import SwiftUI
import CoreData

struct NotificationsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AppNotification.createdAt, ascending: false)],
        animation: .default
    )
    private var notifications: FetchedResults<AppNotification>

    var body: some View {
        List {
            if notifications.isEmpty {
                ContentUnavailableView(
                    "Нет уведомлений",
                    systemImage: "bell.slash",
                    description: Text("Здесь будут отображаться уведомления о новых и обновлённых играх")
                )
                .foregroundStyle(.white)
                .listRowBackground(Color.clear)
            } else {
                ForEach(notifications, id: \.objectID) { notification in
                    NotificationRowView(notification: notification)
                        .onTapGesture {
                            markAsRead(notification)
                            if let gameId = notification.gameId {
                                NotificationCenter.default.post(name: .openGameFromNotification, object: gameId)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .onDelete(perform: deleteNotifications)
            }
        }
        .accessibilityIdentifier("notifications_view_root")
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .v2ScreenBackground()
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func markAsRead(_ notification: AppNotification) {
        notification.isRead = true
        try? viewContext.save()
    }

    private func deleteNotifications(at offsets: IndexSet) {
        offsets.map { notifications[$0] }.forEach(viewContext.delete)
        try? viewContext.save()
    }
}

struct NotificationRowView: View {
    let notification: AppNotification

    private var dateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.localizedString(for: notification.createdAt, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(notification.isRead ? .white.opacity(0.65) : .white)
                Spacer()
                Text(dateString)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.45))
            }
            Text(notification.body)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardStyle(.plain)
    }
}
