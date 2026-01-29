//
//  ClaimStatusView.swift
//  PokerCardRecognizer
//
//  Created by Cursor Agent on 21.12.2025.
//

import SwiftUI
import CoreData

struct ClaimStatusView: View {
    let gameWithPlayer: GameWithPlayer
    let userId: UUID
    
    private let claimService = PlayerClaimService()
    
    private var claim: PlayerClaim? {
        let myClaims = claimService.getMyClaims(userId: userId)
        let objectIdString = gameWithPlayer.objectID.uriRepresentation().absoluteString
        return myClaims.first { claim in
            claim.gameWithPlayerObjectId == objectIdString
        }
    }
    
    var body: some View {
        if let claim = claim {
            HStack(spacing: 4) {
                Image(systemName: statusIcon)
                    .font(.caption)
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .cornerRadius(6)
        }
    }
    
    private var statusIcon: String {
        guard let claim = claim else { return "" }
        switch claim.status {
        case "pending": return "clock.fill"
        case "approved": return "checkmark.circle.fill"
        case "rejected": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }
    
    private var statusColor: Color {
        guard let claim = claim else { return .gray }
        switch claim.status {
        case "pending": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
    
    private var statusText: String {
        guard let claim = claim else { return "" }
        switch claim.status {
        case "pending": return "Заявка ожидает"
        case "approved": return "Заявка одобрена"
        case "rejected": return "Заявка отклонена"
        default: return claim.status
        }
    }
}

