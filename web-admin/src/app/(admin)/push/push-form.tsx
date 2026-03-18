"use client";

import { useState } from "react";
import { sendPushNotification } from "./actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Loader2, Send, Bell } from "lucide-react";
import { toast } from "sonner";
import { format } from "date-fns";

interface PushLog {
  id: string;
  title: string;
  body: string;
  sent: number;
  target: string;
  sentAt: Date;
}

export function PushForm({ deviceCount }: { deviceCount: number }) {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [target, setTarget] = useState<"all" | "specific">("all");
  const [userId, setUserId] = useState("");
  const [sending, setSending] = useState(false);
  const [logs, setLogs] = useState<PushLog[]>([]);

  async function handleSend() {
    if (!title.trim() || !body.trim()) {
      toast.error("Title and body are required");
      return;
    }
    setSending(true);
    try {
      const result = await sendPushNotification(
        title,
        body,
        target,
        target === "specific" ? userId : undefined
      );

      if (result.success) {
        toast.success(`Push sent to ${result.sent} devices`);
        setLogs((prev) => [
          {
            id: crypto.randomUUID(),
            title,
            body,
            sent: result.sent,
            target: target === "all" ? "All users" : `User: ${userId}`,
            sentAt: new Date(),
          },
          ...prev,
        ]);
        setTitle("");
        setBody("");
      } else {
        toast.error(result.error ?? "Failed to send push");
      }
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="space-y-6 max-w-2xl">
      <Card>
        <CardHeader>
          <CardTitle className="text-sm flex items-center gap-2">
            <Bell className="w-4 h-4" />
            Send Push Notification
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-2 px-3 py-2 rounded-md bg-muted text-sm text-muted-foreground">
            <Bell className="w-3.5 h-3.5" />
            {deviceCount} device{deviceCount !== 1 ? "s" : ""} registered
          </div>

          <div className="space-y-2">
            <Label>Target</Label>
            <Select value={target} onValueChange={(v) => setTarget(v as "all" | "specific")}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All users</SelectItem>
                <SelectItem value="specific">Specific user</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {target === "specific" && (
            <div className="space-y-2">
              <Label>User ID</Label>
              <Input
                placeholder="uuid-of-user"
                value={userId}
                onChange={(e) => setUserId(e.target.value)}
              />
            </div>
          )}

          <div className="space-y-2">
            <Label>Title</Label>
            <Input
              placeholder="Notification title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={100}
            />
          </div>

          <div className="space-y-2">
            <Label>Body</Label>
            <Input
              placeholder="Notification body"
              value={body}
              onChange={(e) => setBody(e.target.value)}
              maxLength={256}
            />
          </div>

          {/* Preview */}
          {(title || body) && (
            <div className="rounded-lg border border-border bg-muted/50 p-4">
              <p className="text-xs text-muted-foreground mb-2">Preview</p>
              <div className="flex items-start gap-3">
                <div className="w-9 h-9 rounded-xl bg-primary flex items-center justify-center text-primary-foreground shrink-0">
                  <Bell className="w-4 h-4" />
                </div>
                <div>
                  <p className="text-sm font-semibold">{title || "Title"}</p>
                  <p className="text-xs text-muted-foreground mt-0.5">
                    {body || "Body"}
                  </p>
                </div>
              </div>
            </div>
          )}

          <Button
            onClick={handleSend}
            disabled={sending || !title.trim() || !body.trim()}
            className="w-full"
          >
            {sending ? (
              <Loader2 className="w-4 h-4 mr-2 animate-spin" />
            ) : (
              <Send className="w-4 h-4 mr-2" />
            )}
            Send Notification
          </Button>
        </CardContent>
      </Card>

      {/* History */}
      {logs.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Send History (this session)</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="divide-y divide-border">
              {logs.map((log) => (
                <div key={log.id} className="py-3">
                  <div className="flex items-start justify-between">
                    <div>
                      <p className="text-sm font-medium">{log.title}</p>
                      <p className="text-xs text-muted-foreground">{log.body}</p>
                    </div>
                    <div className="text-right shrink-0 ml-4">
                      <p className="text-xs font-medium text-green-500">
                        {log.sent} sent
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {format(log.sentAt, "HH:mm:ss")}
                      </p>
                    </div>
                  </div>
                  <p className="text-xs text-muted-foreground mt-1">
                    → {log.target}
                  </p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
