"use client";

import { useState } from "react";
import { updateClaimStatus } from "./actions";
import { Button } from "@/components/ui/button";
import { Check, X, Loader2 } from "lucide-react";
import { toast } from "sonner";

interface ClaimActionsProps {
  claimId: string;
  status: string;
}

export function ClaimActions({ claimId, status }: ClaimActionsProps) {
  const [loading, setLoading] = useState<"approve" | "reject" | null>(null);

  if (status !== "pending") {
    return null;
  }

  async function handle(action: "approve" | "reject") {
    setLoading(action);
    try {
      await updateClaimStatus(
        claimId,
        action === "approve" ? "approved" : "rejected"
      );
      toast.success(action === "approve" ? "Claim approved" : "Claim rejected");
    } catch (e) {
      toast.error(String(e));
    } finally {
      setLoading(null);
    }
  }

  return (
    <div className="flex gap-2">
      <Button
        size="sm"
        variant="outline"
        className="text-green-600 border-green-600/40 hover:bg-green-600/10"
        onClick={() => handle("approve")}
        disabled={loading !== null}
      >
        {loading === "approve" ? (
          <Loader2 className="w-3.5 h-3.5 animate-spin" />
        ) : (
          <Check className="w-3.5 h-3.5" />
        )}
      </Button>
      <Button
        size="sm"
        variant="outline"
        className="text-red-600 border-red-600/40 hover:bg-red-600/10"
        onClick={() => handle("reject")}
        disabled={loading !== null}
      >
        {loading === "reject" ? (
          <Loader2 className="w-3.5 h-3.5 animate-spin" />
        ) : (
          <X className="w-3.5 h-3.5" />
        )}
      </Button>
    </div>
  );
}
