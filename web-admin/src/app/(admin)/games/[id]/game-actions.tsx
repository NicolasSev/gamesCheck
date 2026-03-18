"use client";

import { useState } from "react";
import { toggleSoftDelete } from "./actions";
import { Button } from "@/components/ui/button";
import { Loader2, Trash2, RefreshCw } from "lucide-react";
import { toast } from "sonner";

interface GameActionsProps {
  gameId: string;
  softDeleted: boolean;
}

export function GameActions({ gameId, softDeleted }: GameActionsProps) {
  const [loading, setLoading] = useState(false);

  async function handleToggle() {
    setLoading(true);
    try {
      await toggleSoftDelete(gameId, softDeleted);
      toast.success(softDeleted ? "Game restored" : "Game deleted");
    } catch (e) {
      toast.error(String(e));
    } finally {
      setLoading(false);
    }
  }

  return (
    <Button
      variant={softDeleted ? "outline" : "destructive"}
      size="sm"
      onClick={handleToggle}
      disabled={loading}
    >
      {loading ? (
        <Loader2 className="w-4 h-4 animate-spin mr-2" />
      ) : softDeleted ? (
        <RefreshCw className="w-4 h-4 mr-2" />
      ) : (
        <Trash2 className="w-4 h-4 mr-2" />
      )}
      {softDeleted ? "Restore" : "Soft Delete"}
    </Button>
  );
}
