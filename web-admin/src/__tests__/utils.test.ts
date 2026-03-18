import { cn } from "@/lib/utils";

describe("cn()", () => {
  it("returns empty string for no args", () => {
    expect(cn()).toBe("");
  });

  it("merges class names", () => {
    expect(cn("foo", "bar")).toBe("foo bar");
  });

  it("merges conditional class names", () => {
    expect(cn("foo", false && "bar", "baz")).toBe("foo baz");
  });

  it("handles undefined and null gracefully", () => {
    expect(cn("a", undefined, null, "b")).toBe("a b");
  });

  it("deduplicates conflicting Tailwind classes (last wins)", () => {
    expect(cn("text-red-500", "text-green-500")).toBe("text-green-500");
  });

  it("keeps non-conflicting Tailwind classes", () => {
    const result = cn("p-2", "text-sm", "font-bold");
    expect(result).toBe("p-2 text-sm font-bold");
  });

  it("handles arrays of classes", () => {
    expect(cn(["a", "b"], "c")).toBe("a b c");
  });

  it("handles object syntax", () => {
    expect(cn({ "text-green-500": true, "text-red-500": false })).toBe(
      "text-green-500"
    );
  });
});
